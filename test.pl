use warnings;
use strict;
use Audio::Wav;
use Data::Dumper;
use List::Util qw |max min|;

my $sample_rate = 44100;
my $bits_sample = 16;

get_wav(38);

sub get_wav {
	my $freq = shift;
	
	my $read = Audio::Wav->new->read('du/power2.wav');
	my $write = Audio::Wav->new->write('test_'.$freq.'.wav', {
		'bits_sample'	=> $bits_sample, 
		'sample_rate'	=> $sample_rate, 
		'channels'		=> 2
	});

	check_file("ok.wav", $read->details(), 1);

	my $info = $read->details();
	my $sample_max = (2 ** $info->{bits_sample}) / 2;
	my $total_samples = ($info->{data_length} * 8 / $info->{bits_sample}) / $info->{channels};

	my $max = 0;
	my $avg = 0;

	my $samples_cnt = 0;
	my $last_value = undef;
	my @values = ();
	while (1) {
		my @channels = $read->read();
		last unless @channels;
		
		$max = max($max, $channels[0]);
		$avg += $channels[0] if ($channels[0] > 0);
		
		my $v = $channels[0] >= ($sample_max / 8) ? 1 : 0;
		if (!defined $last_value || $last_value != $v) {
			if (defined $last_value) {
				for (my $i = 0; $i < $samples_cnt; ++$i) {
					push @values, $last_value;
				}
				print "$last_value\t$samples_cnt\n";
			}
			$last_value = $v;
			$samples_cnt = 1;
		} else {
			++$samples_cnt;
		}
	}
	$avg /= $total_samples;

	print "\n";
	print "max amplitude = $max (".sprintf("%.04f", $max / $sample_max * 100)."%)\n";
	print "avg amplitude = $avg (".sprintf("%.04f", $avg / $sample_max * 100)."%)\n";

	my $pattern = Audio::Wav->new->read('du/'.$freq.'_khz.wav');
	check_file($freq."_khz.wav", $pattern->details(), 2);

	my $offset = 0;
	while (1) {
		my @channels = $pattern->read();
		last unless (@channels);
		
		if (!exists($values[$offset])) {
			print "Done\n";
			last;
		}
		
		if (!$values[$offset]) {
			$channels[0] = 0;
			$channels[1] = 0;
		}
		
		$write->write(@channels);
		++$offset;
	}
	$write->finish();
}

sub check_file {
	my ($file, $info, $nc) = @_;
	print Dumper($info);
	die "$file: allow only $nc channels!\n"
		if ($info->{channels} != $nc);
	die "$file: allow only $bits_sample bit sample!\n"
		if ($info->{bits_sample} != $bits_sample);
	die "$file: allow only $sample_rate sample rate!\n"
		if ($info->{sample_rate} != $sample_rate);
}
