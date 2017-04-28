package Command;
use 5.010;

use Moose;
use Carp;
use overload
	'""' => sub { shift->get },
	fallback => 1;


# ensures the proper format for constructor arguments
around BUILDARGS => sub {
	my ( $orig, $self, %args ) = @_;
	
	my ( $type, $command ) = each %args;
	
	ERROR_CHECKS: {
		return carp "WARNING set_command error: invalid command type \"$type\""
			unless Container->can( $type );
	}
	
	return $self->$orig( command_type => $type, command => $command );
};


has 'command_type' => ( is => 'ro', isa => 'Str', reader => 'type', required => 1, );
has 'command' => (  is  => 'ro', isa => 'Str', reader => 'get', required => 1, );


1;
__PACKAGE__->meta->make_immutable;