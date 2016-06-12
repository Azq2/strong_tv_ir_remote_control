use warnings;
use strict;
use Audio::Wav;
use Data::Dumper;
use List::Util qw |max min|;

my $sample_rate = 44100;
my $bits_sample = 16;

my $LEADING_PULSE	= 9;
my $LEADING_SPACE	= 4.5;
my $BIT_START		= 0.5625;
my $BIT_TRUE		= $BIT_START;
my $BIT_FALSE		= $BIT_START * 3;
my $END_PULSE		= 0.5625;
my $REPEAT_SPACE	= 2.25;
my $REPEAT_DELAY	= 40;
my $REPEAT_INTERVAL	= 108;

my $codes = "
# 07 - OK
# 17 - 7
# 37 - 3
# 57 - 5
# 67 - 9
# 77 - 1
# 97 - 6
# B7 - 2
# D7 - 4
# E7 - 8
# F7 - 0
# 4D - key?
# 87 - films? fav?
# C5 - SUB
# C7 - TV program
# CD - channel minus
# E5 - channel plus
# FD - return?
# AF - power
# EF - menu
# 8F - language?
# DF - Screen format
# 9F - EXIT
# FF - UP
# 7F - DOWN
# 3F - LEFT
# BF - RIGHT
# 0F - Volume
";

#get_wav(38, 0xED11, -1);
#while ($codes =~ m/# ([A-F0-9]{2})\s-/g) {
#	print "$1\n";
#	get_wav(38, 0xED11, hex $1);
#}
#exit;
#get_wav(38, 0xED11, hex $ARGV[0]);
#exit;

for (my $i = 0xFF; $i <= 0xBF; ++$i) {
	if ($i != 0xAF) {
		printf("%02X\n", $i);
		get_wav(38, 0xED11, $i);
		<STDIN>;
		# get_wav(38, 0xED, hex $ARGV[0]);
	}
}

sub get_wav {
	my ($freq, $addr, $code) = @_;
	
	my $pattern = Audio::Wav->new->read('tmp/'.$freq.'_khz.wav');
	check_file($freq."_khz.wav", $pattern->details(), 2);
	
	my $bin;
	my $data = [];
	
	my $file = sprintf("/tmp/key_%02X.wav", $code);
	if ($code == -1) {
		$file = sprintf("/tmp/key_repeat.wav", $code);
		for my $i (0..10) {
			# Repeat
			push @$data, [$LEADING_PULSE, 1];
			push @$data, [$REPEAT_SPACE, 0];
			push @$data, [$END_PULSE, 1];
			push @$data, [$REPEAT_INTERVAL, 0];
		}
	} else {
		# start
		push @$data, [$LEADING_PULSE, 1];
		push @$data, [$LEADING_SPACE, 0];
		
		# addr
		$bin = sprintf("%16b", $addr);
		for my $i (0..15) {
			push @$data, [$BIT_START, 1];
			push @$data, [substr($bin, $i, 1) == 1 ? $BIT_TRUE : $BIT_FALSE, 0];
		}
		
		# cmd
		$bin = sprintf("%08b", $code);
		for my $i (0..7) {
			push @$data, [$BIT_START, 1];
			push @$data, [substr($bin, $i, 1) == 1 ? $BIT_TRUE : $BIT_FALSE, 0];
		}
		
		# cmd xor
		$bin = sprintf("%08b", ~$code & 0xFF);
		for my $i (0..7) {
			push @$data, [$BIT_START, 1];
			push @$data, [substr($bin, $i, 1) == 1 ? $BIT_TRUE : $BIT_FALSE, 0];
		}
		
		# END
		push @$data, [$END_PULSE, 1];
		
		# Repeat delay
		push @$data, [$REPEAT_DELAY, 0];
		
		for my $i (0..0) {
			# Repeat
			push @$data, [$LEADING_PULSE, 1];
			push @$data, [$REPEAT_SPACE, 0];
			push @$data, [$END_PULSE, 1];
			push @$data, [$REPEAT_INTERVAL, 0];
		}
	}
	
	
	my $write = Audio::Wav->new->write($file, {
		'bits_sample'	=> $bits_sample, 
		'sample_rate'	=> $sample_rate, 
		'channels'		=> 2
	});
	
	
	my @values = ();
	for my $sample (@$data) {
		my $n = int($sample->[0] * ($sample_rate / 1000) + 0.5);
		for (my $i = 0; $i < $n; ++$i) {
			push @values, int($sample->[1]);
		}
	}
	
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
	system("mplayer '$file' 2>&1 >/dev/null");
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
