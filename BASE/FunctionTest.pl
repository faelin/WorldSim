#!/usr/bin/perl

use 5.010;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::Simple tests => 100;
use Benchmark;
my $t0 = Benchmark->new;

use Namespace;

INITIALIZATION: {
	our $verbose = shift @ARGV // 0;	# higher $verbose value means more debug
	
	open STDERR, '>>', 'logfile.log'
		or die "Can't open logfile: $!";
	say STDERR "\n\n" . localtime . "\n";
	
	our %buffer;
	our %spaces = ( NULL => Namespace->new( name => 'null_space' ) );
}

say STDERR;

FIRST_TEST: if (shift @ARGV // 1) {
	say STDERR "1 - multiple namespace creation test (2 tests) -";
		ok(( my $ns = Namespace->new( name => 'PRIMARY' )) eq 'PRIMARY' =>
			'Namespace "PRIMARY" generated' );
		ok(( my $secondary = Namespace->new( name => 'SECONDARY' )) eq 'SECONDARY' =>
			'Namespace "SECONDARY" generated' );

	say STDERR "\n\n2 - region creation test (2 tests) -";
		ok(( my $parent = Region->new( name => 'Parent', namespace => $ns )) eq 'Parent' =>
			'Region "Parent" generated' );
		ok(( my $child = Region->new( name => 'Child', namespace => $ns )) eq 'Child' =>
			'Region "Child" generated' );
 
	say STDERR "\n\n3 - region default creation and modification test (3 tests) -";
		ok(( my $empty_region = Region->new ) eq 'UNNAMED' =>
			'Region "UNNAMED" generated' );
		ok( $empty_region->set_name( "Empty" ) eq 'Empty' =>
			'Region "UNNAMED" renamed to "empty"' );
		ok( $empty_region->set_namespace( $ns ) eq $ns =>
			'Region "UNNAMED" spawned in "PRIMARY"' );

	say STDERR "\n\n4 - region adoption test (1 test) -";
		ok( $child->set_parent( $parent) eq $parent =>
			'"child" adopted into "parent"' );

	say STDERR "\n\n5 - region inline creation and adoption test (1 test) -";
		ok( $empty_region->set_child( Region->new ) eq $empty_region =>
			'"UNNAMED" adopted into "Empty"' );

	say STDERR "\n\n6 - multi-element adoption test (2 tests) -";
		ok(( $pool = Pool->new( name => 'WOOD', namespace => $ns )) eq 'WOOD' =>
			'Pool "WOOD" generated' );
		ok( $child->set_child( $pool, Pool->new( name => 'ALUMINUM', namespace => $ns )) eq 'Child' =>
			'Pools "WOOD", "ALUMINUM" adopted into "Child"' );

	say STDERR "\n\n7 - flow inline creation and adoption test (1 test) -";
		ok( $child->set_child( Flow->new( dest => $parent, type => $pool, rate => 1, namespace => $ns ) ) eq 'Child' =>
			'Flow "WOOD into Parent" adopted into "Child"' );

	say STDERR "\n\n8 - subregion overwhelm test (2 test) -";
		ok( Region->new( namespace => $ns )->set_parent( $empty_region ) eq 'Empty' =>
			'Region "UNNAMED" adopted into "Empty"' );
		ok( $child->set_child( $parent ) ne 'Parent' =>
			'Recursive adoption test successful' );

	say STDERR "\n\n9 - pool control test (5 tests) -";
		ok(( $pool += 5 ) == 5, 'Pool "WOOD" swell 5' );
		ok(( $pool += -$pool + 4 ) == 4, 'Pool "WOOD" drain 1' );
		ok(( $pool -= 10 ) == 0, 'Pool "WOOD" drain 10' );
		ok(( $pool -= -1 ) == 1, 'Pool "WOOD" swell 5' );
		ok(( $pool-- ) == 0, 'Pool "WOOD" drain 1' );

	
	say STDERR $ns->list_children if ( $verbose < 1 );
	say STDERR "=====================================================================";
	say STDERR;
}

SECOND_TEST: if (shift @ARGV // 1) {
	say STDERR "\n1 - namespace id test (1 test) -";
	ok(( my $ns = Namespace->new( name => 'MAIN', id => 'A000' ) ) eq 'MAIN' =>
			'Namespace "MAIN" generated' );
	say STDERR "\n";

	say STDERR "\n2 - timeline creation and inline emplacement test (3 tests) -";
	ok(( my $timeline = Timeline->new( name => 'main/line' ) ) eq 'main|line' =>
		'Timeline "main|line" generated' );
	ok(( my $event1 = Event->new( name => 'event1', ns => $ns ) ) eq 'event1' =>
		'Event "event1" generated' );
	ok( $timeline->give( 0 => $event1 ) eq 'main|line' =>
		'Event "event1" generated at "0" in "main|line"' );
	say STDERR "\n";

	say STDERR "\n3 - event population test (3 tests) -";
	ok(( my $test_command = Command->new( give => 'Region->new( name => "Test_region" )' ) ) =>
		'Command "Test_region" generated' );
	ok( $event1->give( $child => $test_command ) eq 'event1' =>
		'Command "Test_region" given to "event1" at "MAIN:Grandparent/Parent/Child/target' );
	ok( $event1->give( Address->new('Test2') => Command->new( give => 'Region->new' ) ) eq 'event1' =>
		'Command "Region->new" given to "event1" at "NULL:Test2' );
	say STDERR "\n";

	say STDERR "\n4 - run event test (1 test) -";
	ok( $event1->run eq 'event1' => 'Ran "event1"' );
	say STDERR "\n";

	say STDERR $ns->list_children if ( $verbose < 1);
	say STDERR "=====================================================================";
	say STDERR;
}

THIRD_TEST: if (shift @ARGV // 1) {
	say STDERR "\n1 - spin up -";
	my $ns = Namespace->new( name => 'SPIN' );
	my $region1 = Region->new( name => '111', ns => $ns );
	my $region2 = Region->new( name => '222', ns => $ns );
	my $region3 = Region->new( name => '333', ns => $ns );
	
	$region1->give( Pool->new( 'WOOD' => 24 ) );
	$region2->give( Pool->new( 'WOOD' => 16 ) );
	$region3->give( Pool->new( 'WOOD' => 12 ) );
	
	$region1->give( Flow->new( 'WOOD' => $region2, rate => 3 ) );
	$region2->give( Flow->new( 'WOOD' => $region3, rate => 4 ) );
	$region3->give( Flow->new( 'WOOD' => $region1, rate => 3 ) );
	say STDERR "\n";

	say STDERR "\n2 - timeline tick test -";
	$ns->tick;
	say STDERR "\n";

	say STDERR "=====================================================================";
	say STDERR "\n";
}

my $t1 = Benchmark->new;
my $td = timediff( $t1, $t0 );
say STDERR "\nTIME: ", timestr($td), "\n";


#unlink glob '.\data\buffer\*.txt';

# serializing time results
# 0.03usr + 0.09sys = 0.12cpu  with big serialize
# 0.03usr + 0.00sys = 0.03cpu  w/o serialize