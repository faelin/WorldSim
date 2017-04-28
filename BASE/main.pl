#!/usr/bin/perl

use 5.010;
use FindBin;
use lib "$FindBin::Bin/lib";
use Benchmark;
use Carp;

no warnings 'experimental::smartmatch';

use Namespace;

my $t0 = Benchmark->new;

INITIALIZATION: {
	our $verbose = shift @ARGV // 0;	# higher $verbose value means more debug

	open STDERR, '>>', 'errlog.log'
		or die "Can't open errlog: $!";
	say STDERR "\n" . "-" x 60 . "\n\n" . localtime . "\n";
	say "" . localtime . "\n";
	
	our %buffer;
	our %spaces = ( NULL => Namespace->new( name => 'null_space' ) );
}


PROMPT: {
	say "Enter a command:";
	print "> ";

	chomp and say STDERR " * User entered '$_' at " . localtime and &interpret ($_) while <>;
}

sub interpret {
	for (shift) {
		say "Terminating" and &terminate when /\A(([Ee]xit)|([Tt]erminate))\Z/;
	}

	return print "\n> ";
}

sub terminate {
	my $t1 = Benchmark->new;
	my $td = timediff( $t1, $t0 );

	say STDERR "___TERMINATED___ at " . localtime . "\n\tRUNTIME: " . timestr($td)
		and die;

	#unlink glob '.\data\buffer\*.txt';
}

# serializing time results
# 0.03usr + 0.09sys = 0.12cpu  with big serialize
# 0.03usr + 0.00sys = 0.03cpu  w/o serialize