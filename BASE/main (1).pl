#!/usr/bin/perl

use 5.010;
use FindBin;
use lib "$FindBin::Bin/lib";
use Benchmark;

use Namespace;

my $t0 = Benchmark->new;

INITIALIZATION: {
	our $verbose = shift @ARGV // 0;	# higher $verbose value means more debug

	open STDERR, '>>', 'errlog.log'
		or die "Can't open errlog: $!";
	say STDERR "\n\n" . localtime . "\n";
	say "" . localtime . "\n";
	
	our %buffer;
	our %spaces = ( NULL => Namespace->new( name => 'null_space' ) );
}


PROMPT: {
	say "Enter a command:";
	print "> ";

	our $input = <>;
}


my $t1 = Benchmark->new;
my $td = timediff( $t1, $t0 );
say STDERR "\nTIME: ", timestr($td), "\n";

#unlink glob '.\data\buffer\*.txt';

# serializing time results
# 0.03usr + 0.09sys = 0.12cpu  with big serialize
# 0.03usr + 0.00sys = 0.03cpu  w/o serialize