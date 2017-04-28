package Flow;
use 5.010;

use Moose;
use Carp;
use overload
	'0+'	=> sub { shift->rate },
	fallback => 1;

with 'Wrapper';		# consumes the 'Wrapper' role


# applies default values for 'name' attribute - overridden by user-supplied value
#	'type' attribute allows Pool reference
#	allows args in the form { TYPE => DEST, rate => RATE }
around BUILDARGS => sub {
	my ($orig, $class, %args) = @_;
	
	#this allows for arguments to be sent as { TYPE => dest, rate }
	#	e.g.	Flow->new( WOOD => regionFoo, rate => 0 );
	for (keys %args) {
		if ( /\A[[:upper:]]+\Z/ ) {
			$args{ 'type' } = $_ ;
			$args{ 'dest' } = $args{ "$_" };
		}
	}
	
	$args{ 'type' } = "$args{ 'type' }";	# stringifies possible Pool reference
	$args{ 'name' } = $args{ 'name' } // "$args{ 'type' } to $args{ 'dest' }";

	return $class->$orig(%args);
};


has 'dest' => ( is => 'ro', isa => 'Container', required => 1, );	# points to the container that holds the destination pool
has 'type' => ( is => 'ro', isa => 'Str', required => 1, );	# string value representing the "material" to be moved
has 'rate' => ( is => 'rw', isa => 'Int', required => 1, writer => 'set_rate', );	# int value that represents the rate of flow per day


# sends $time, in seconds, worth of material to the destination pool
sub send {
	my ( $self, $time ) = @_;
	my $amount;
	
	ERROR_CHECKS: {
		return carp "WARNING Flow error: Flow $self cannot send without a parent source"
			unless $self->parent;
			
		return carp sprintf "Flow exception: missing Pool %s in parent %s %s",
			$self->type, ref $self->parent, $self->parent
			
			unless $self->parent->_has_pool( $self->type );
		return carp "Flow exception: time $time is less than zero"
			if $time < 0;
			
		return if $time == 0;
	}
	
	my $near_pool = $self->parent->_get_pool( $self->type );	# parent pool
	my $far_pool = $self->dest->give( Pool->new( $self->type => 0 ) );	# dest pool
	#	$far_pool returns the appropriate pool at the dest Region, or creates a new one

	# sets the $amount by which to update each pool
	if ( $near_pool - $self->rate*$time < 0 ) {
		$amount = $near_pool->size;	# empties the $near_pool if it does not have enough to complete the send
	} else {
		$amount = $self->rate * $time;
	}
	
	$near_pool -= $amount;
	$far_pool += $amount;
	
	return $self;
};


# test to determine if ->send($time) is smaller than the provided pool
sub test_send {
	my ( $self, $time ) = @_;

	ERROR_CHECKS: {
		return carp "WARNING test_send error: Flow $self cannot test without a parent source"
			unless $self->parent;
		return carp "test_send exception: time $time is less than zero"
			if $time < 0;
	}

	# this returns the appropriate type of pool from the parent, if it does not exist
	my $near_pool = $self->parent->_get_pool( $self->type ) // 0;
	my $amount = $self->rate*$time;
	
	return $near_pool - $amount;
}


1;
__PACKAGE__->meta->make_immutable;