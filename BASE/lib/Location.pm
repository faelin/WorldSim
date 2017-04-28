package Location;
use 5.010;

use Moose;
use overload
	'==' => sub { 	my ( $self, $other ) = @_;
					ref $other eq 'Location' ?
						( $self->lat == $other->lat
						and $self->long == $other->long ) : 0 },
	fallback => 1;

with 'Wrapper';


# applies default values for 'name' attribute - overridden by user-supplied value
around BUILDARGS => sub {
	my ($orig, $class, %args) = @_;
	
	$args{ 'long' } = $args{ 'long' } // 0;
	$args{ 'lat' } = $args{ 'lat' } // 0;
	$args{ 'name' } = $args{ 'name' } // "($args{ 'long' }, $args{ 'lat' })";

	return $class->$orig(%args);
};


has ['long', 'lat'] => ( is  => 'ro', isa => 'Num', required => 1, );	# longitude and latitude, represented as real numbers


1;
__PACKAGE__->meta->make_immutable;