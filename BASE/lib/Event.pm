package Event;
#use 5.014;
use 5.010;

use Moose;
use Carp;
use overload
	fallback => 1;
	
use Address;
use Command;

with 'Container'
	=> { -excludes => [ 'parent', 'pools', 'flows' ], };


# HashRef representing the new and updated objects to be put into play
#	Organized by { Address => Region }
#	Keys are in the form of "/grandparent/.../parent/target/object"
#	 where "target" is the destination container for the specified object
#	 and "object" is its name
has 'commands' => ( traits  => ['Hash'], is  => 'ro', isa => 'HashRef[Command]',
    handles => {
		_set_command	=> 'set',
		_kill_command	=> 'delete',
		_has_command	=> 'defined',
		_get_command	=> 'get',
		_command_keys	=> 'keys',
		_command_vals	=> 'values',
		_command_count	=> 'count',
		_command_pairs	=> 'kv',
    },
);


around '_set_command' => sub {
	my ( $orig, $self, $object, $command ) = @_;
	
	my $address = $object->address;
	
	ERROR_CHECKS: {
		return carp "WARNING set_command error: \"$command\" is not a valid command"
			if ref $command ne 'Command' or $command eq 'NULL';
		return carp "WARNING set_command error: \"$address\" is not a valid address"
			unless $address =~ m#\A  \w+  :  (:?  [^/]+? / )*?  [^/]+?  \Z#six;#u;
	}

	DEBUG_OUTPUT:{
		printf STDERR "WARNING set_command error: there is already a command at \"$address\""
			if $self->_has_command( $address ) and $main::verbose < 6;
		printf STDERR "      put   \"%s( %s )\"   for   \"%s\"   into   %s\n",
			$command->type, $command, $address, $self
			if $main::verbose < 6;
	}

	return $self->$orig( $address => $command );
};


# adds commands to this event in the form of { Address => Command }
#	can take multiple commands at once
sub give {
	my $self = shift;
	my ( $object, $command );

	$self->_set_command( $object, $command ) while $object = shift and $command = shift;
	#	Event->_set_command takes ( address => command )
	
	return $self;
};


# Transforms command_keys and command_vals into live actions
#	keys are in the form of "/grandparent/.../parent/target/object"
#	vals are in the form of "WRAPPER_TYPE->new( ... )"
sub decode {
	my ( $self, $address ) = @_;
	my ( $namespace, $parent, $command, $sub, $obj_ref );
	
	$command = $self->_get_command( $address );	# retrieve the command at the provided address
	$sub = $command->type;
	
	( $namespace, $address ) = split ':' => $address;
	#	retrieve the namespace indicated by the address
	
	$parent = $main::spaces{ $namespace }->search( $address );
	#	attempts to find the parent region if one is indicated by the address
	
	$obj_ref = $parent ? $parent->$sub( eval $command ) : eval $command;
	
	return carp "WARNING command error: invalid command \"$sub$command\" -\n\t$@" if $@;	# returns a carp if $@ contains an error
	
	return $obj_ref;
};


# Runs every command owned by this Event
sub run {
	my $self = shift;
	
	$self->decode( $_ ) for sort $self->_command_keys;
	
	return $self
}


__PACKAGE__->meta->make_immutable;