package Address;

#use 5.014;
use 5.010;

use Moose;
use Carp;
use overload
	'""' => sub { shift->address },
	fallback => 1;


# ensures the proper format for constructor arguments
around BUILDARGS => sub {
	my ( $orig, $self, $address ) = @_;
	
	$address = $address->address if $address->can( 'to_address' );

	$address = "NULL:$address" unless $address =~ m#\A  \w+  :  \Z#six;#u;
	
	ERROR_CHECKS: {
		return carp "WARNING set_address error: invalid address \"$address\""
			unless $address =~ m#\A  \w+  :  (:?  [^/]+? / )*?  [^/]+?  \Z#six;#u;
			#	matches a properly formatted address
	}

	return $self->$orig( address => "$address" );
};


has 'address' => ( is  => 'ro', isa => 'Str', );


1;
__PACKAGE__->meta->make_immutable;