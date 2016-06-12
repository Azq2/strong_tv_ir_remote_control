use strict;
use warnings;
use IO::Socket::INET;
use Data::Dumper;
use Audio::Wav;
use File::Basename qw(dirname);

$| = 1;

my $HOME = dirname(__FILE__);

my $socket = new IO::Socket::INET (
	LocalHost => '0.0.0.0',
	LocalPort => '9991',
	Proto => 'tcp',
	Listen => 5,
	Reuse => 1
);
 
while (1) {
	my $client_socket = $socket->accept();
	
	$client_socket->send("XUJ!\n");
	
	my $data = "";
	$client_socket->recv($data, 1024);
	
	if ($data =~ /^[A-F0-9]+$/) {
		$data =~ s/^\s+|\s+$//g;
		
		print "keycode: '$data'\n";
		system("aplay -D'hw:CARD=CODEC,DEV=0' ".get_wav(38, 0xED11, hex $data));
	}
	
	$client_socket->send("OK\n");
	shutdown($client_socket, 1);
}

sub get_wav {
	my ($freq, $addr, $code) = @_;
	
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
	
	my $file = "$HOME/".sprintf("cache/key_%dkhz_%04X_%02X.wav", $freq, $addr, $code);
	
	if (-f $file) {
		# есть в кэше
		return $file;
	}
	
	my $pattern = Audio::Wav->new->read("$HOME/patterns/".$freq."_khz.wav");
	
	my $bin;
	my $data = [];
	
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
	
	return $file;
}
