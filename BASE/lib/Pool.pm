package Pool;
use 5.010;

use Moose;
use Carp;
use overload
	'0+'	=> sub { shift->size },
	'+='	=> 'swell',
	'-=' 	=> 'drain',
	fallback => 1;

with 'Wrapper';

# applies default values for 'name' attribute - overridden by user-supplied value
#	allows args in the form { TYPE => SIZE }
around BUILDARGS => sub {
	my ($orig, $class, %args) = @_;

	#this allows for arguments to be sent as { TYPE => size }
	#	e.g.	Pool->new( WOOD => 0 );
	for (keys %args) {
		if ( /\A[[:upper:]]+\Z/ ) {
			$args{ 'name' } = $_ ;
			$args{ 'size' } = $args{ "$_" };
		}
	}

	return $class->$orig(%args);
};


has 'size' => ( is => 'ro', isa => 'Int', writer => 'set_size', default => 0, );	# int value representing the quantity of the "material" in this pool


sub type { return shift->name }


sub swell {
	my ( $self, $swell ) = @_;
	
	return $self->drain( -$swell ) if $swell < 0;
	
	$self->set_size( $self->size + $swell );
	DEBUG_OUTPUT: {
		if ( $main::verbose < 6.5 ) {
			$self->parent ?
				printf STDERR '%-8s %-15s pool %-8s size increased to %d   (swell %d)' . "\n",
					ref $self->parent, $self->parent, $self, $self, $swell :
				printf STDERR '      pool %-8s size increased to %d   (swell %d)' . "\n",
					$self, $self, $swell;
		}
	}
	
	return $self;
}


sub drain {
	my ( $self, $drain ) = @_;
	
	return $self->swell( -$drain ) if $drain < 0;
	
	$self->set_size( 0 ) if $self->set_size( $self->size - $drain ) < 0;
	
	DEBUG_OUTPUT: {
		if ( $main::verbose < 6 ) {
			$self->parent ?
				printf STDERR '%-8s %-15s pool %-8s size decreased to %d   (drain %d)' . "\n",
					ref $self->parent, $self->parent, $self, $self, $drain :
				printf STDERR '      pool %-8s size decreased to %d   (drain %d)' . "\n",
					$self, $self, $drain;
		}
	}
	
	return $self;
}


1;
__PACKAGE__->meta->make_immutable;