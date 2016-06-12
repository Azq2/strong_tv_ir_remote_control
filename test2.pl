use warnings;
use strict;
use Audio::Wav;
use Data::Dumper;
use List::Util qw |max min|;

my $sample_rate = 44100;
my $bits_sample = 16;

my $read = Audio::Wav->new->read('tmp/power2.wav');
my $info = $read->details();
my $sample_max = (2 ** $info->{bits_sample}) / 2;
my $total_samples = ($info->{data_length} * 8 / $info->{bits_sample}) / $info->{channels};
my $sample_duration = $info->{length} / $total_samples * 1000;

print "sample_duration = $sample_duration\n";

my $max = 0;
my $avg = 0;

my $LEADING_PULSE	= 9;
my $LEADING_SPACE	= 4.5;
my $BIT_START		= 0.5625;
my $BIT_TRUE		= $BIT_START;
my $BIT_FALSE		= $BIT_START * 3;
my $END_PULSE		= 0.5625;
my $REPEAT_PULSE	= 2.25;

my @commands = ();

my $cmd;
my $samples_cnt = 0;
my $last_value = undef;
my $state = 0;
my $index = 0;
my $bits_cnt = 0;
my $bits_data = "";

while (1) {
	my @channels = $read->read();
	last unless @channels;
	
	$max = max($max, $channels[0]);
	$avg += $channels[0] if ($channels[0] > 0);
	
	my $v = $channels[0] >= 712 ? 1 : 0;
	if (!defined $last_value || $last_value != $v) {
		if (defined $last_value) {
			my $time = $sample_duration * $samples_cnt;
			
			if ($state == 0) { # Первый тайминг
				if ($time >= $LEADING_PULSE - 0.9 && $time <= $LEADING_PULSE + 0.9 && $last_value) {
					print "LEADING_PULSE at ".($index * $sample_duration)."\n";
					$state = 1;
					$bits_data = "";
					$bits_cnt = 0;
					$cmd = {};
				}
			} elsif ($state == 1) { # Второй тайминг
				if ($time >= $REPEAT_PULSE - 0.6 && $time <= $REPEAT_PULSE + 0.6 && !$last_value) {
					print "REPEAT_PULSE at ".($index * $sample_duration)."\n";
					$state = 5;
				} elsif ($time >= $LEADING_SPACE - 0.6 && $time <= $LEADING_SPACE + 0.6 && !$last_value) {
					print "LEADING_SPACE at ".($index * $sample_duration)."\n";
					$state = 2;
				} else {
					print "Unexpected $last_value ($time ms) at ".($index * $sample_duration)."\n";
					$state = 0;
				}
			} elsif ($state == 2) { # Здесь читаем первую часть бита (она всегда 1)
				if ($time >= $BIT_START - 0.1 && $time <= $BIT_START + 0.1 && $last_value) {
					print "BIT_START at ".($index * $sample_duration)."\n";
					$state = 3;
				} else {
					print "Unexpected $last_value ($time ms) at ".($index * $sample_duration)."\n";
					$state = 0;
				}
			} elsif ($state == 3) { # Здесь читаем вторую часть бита (она всегда 0)
				if ($time >= $BIT_TRUE - 0.1 && $time <= $BIT_TRUE + 0.1 && !$last_value) {
					print "BIT_TRUE at ".($index * $sample_duration)."\n";
					$bits_data .= "1";
					$state = 2;
					++$bits_cnt;
				} elsif ($time >= $BIT_FALSE - 0.3 && $time <= $BIT_FALSE + 0.3 && !$last_value) {
					print "BIT_FALSE at ".($index * $sample_duration)."\n";
					$bits_data .= "0";
					$state = 2;
					++$bits_cnt;
				} else {
					print "Unexpected $last_value ($time ms) at ".($index * $sample_duration)."\n";
					$state = 0;
				}
				
				if ($state != 0 && $bits_cnt % 8 == 0) {
					if ($bits_cnt / 8 == 1) {
						print "ADDRESS: $bits_data\n";
						$cmd->{addr} = $bits_data;
					} elsif ($bits_cnt / 8 == 2) {
						print "ADDRESS: $bits_data (XOR)\n";
					} elsif ($bits_cnt / 8 == 3) {
						print "COMMAND: $bits_data\n";
						$cmd->{cmd} = $bits_data;
					} elsif ($bits_cnt / 8 == 4) {
						print "COMMAND: $bits_data (XOR)\n";
						$state = 4;
						push @commands, $cmd;
					}
					$bits_data = "";
					print "---\n";
				}
			} elsif ($state == 4) {
				if ($time >= $END_PULSE - 0.1 && $time <= $END_PULSE + 0.1 && $last_value) {
					print "END_PULSE at ".($index * $sample_duration)."\n";
					$state = 0;
				} else {
					print "Unexpected $last_value ($time ms) at ".($index * $sample_duration)."\n";
					$state = 0;
				}
			}
			
			# print "$last_value\t$samples_cnt (".sprintf("%.04f", $sample_duration * $samples_cnt)." ms)\n";
		}
		$last_value = $v;
		$samples_cnt = 1;
	} else {
		++$samples_cnt;
	}
	++$index;
}
$avg /= $total_samples;

print "\n\n--- commands ---\n";
for my $cmd (@commands) {
	print sprintf("%02X | %02X\n", oct("0b".$cmd->{addr}), oct("0b".$cmd->{cmd}));
}

print "\n";
print "max amplitude = $max (".sprintf("%.04f", $max / $sample_max * 100)."%)\n";
print "avg amplitude = $avg (".sprintf("%.04f", $avg / $sample_max * 100)."%)\n";

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
