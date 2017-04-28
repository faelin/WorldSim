package Wrapper;
use 5.010;

use Moose::Role;
use Moose::Util::TypeConstraints;
use Carp;
use overload
	'""' => sub { shift->name },
	'eq' => '_equals',
	fallback => 1;


# ensures the proper format for constructor arguments
around BUILDARGS => sub {
	my ( $orig, $self, %args ) = @_;

	$args{ 'namespace' } = $args{ 'ns' } if $args{ 'ns' };	# uses "ns" as short argument-name for Namespace

	# replaces forward-slashes with pipes in Wrapper names
	$args{ 'name' } =~ s#/#|#;

	return $self->$orig(%args);
};


# adds this Wrapper to its indicated namespace
sub BUILD {
	my $self = shift;
	
	return $self->namespace->give( $self );
};


# type-checking block:
class_type 'Region' => { class => 'Region' };
role_type 'Container' => { role => 'Container' };


# attribute block
has 'name'		=> ( is => 'ro', isa => 'Str', 			writer => 'set_name', 		required => 1, );	# string identifier for the Wrapper
has 'namespace'	=> ( is => 'ro', isa => 'Namespace', 	writer => 'set_namespace',	clearer => 'kill_namespace',	default => sub{ $main::spaces{ 'NULL' } }, );	# reference to the parent Namespace of this Wrapper
has 'id' 		=> ( is => 'ro', isa => 'Str', 			writer => 'set_id', 		clearer => 'kill_id',			init_arg => undef, predicate => 'has_id', );	# unique ID number as assigned by the parent Namespace
has 'parent'	=> ( is => 'ro', isa => 'Container', 	writer => 'set_parent',		clearer => 'kill_parent', );	# reference to a parent container
has 'address'	=> ( is => 'ro', isa => 'Str',			builder => 'to_address',	clearer => 'kill_address',		lazy => 1, );

before 'kill_parent' => sub { $_->parent->disown( $_ ) for shift };	# removes this object from the appropriate HashRef of its old parent
before 'kill_namespace' => sub { $main::spaces{ 'NULL' }->give( @_ ) };	# moves this object to null_space


# ensures the proper format for $new_name
#	and updates the cache in namespace to ensure there are no false references
around 'set_name' => sub {
	my ( $orig, $self, $new_name ) = @_;
	$new_name =~ s#/#|#;

	ERROR_CHECKS: {
		return carp 'WARNING set_name error: cannot rename pools'
			if ref $self eq 'Pool';
		
		return carp "WARNING set_name error: parent \"$self->{parent}\" already has a child named \"$new_name\"",
			if $self->parent and defined $self->parent->get( $new_name );
			#	checks that there is not a Wrapper with this Wrapper's name already in the new parent
	}

	DEBUG_OUTPUT: {
		printf STDERR "      renamed  %-15s  as   %s\n",
			$self, $new_name
			if $main::verbose < 4;
	}

	$self->parent ? $self->parent->disown( $self ) : $self->namespace->_clean_cache( $self );

	$self->$orig( $new_name );

	return $self->parent ? $self->parent->give( $self ) : $self;
};


around 'set_parent' => sub {
	my ( $orig, $child, $new_parent ) = @_;
	my $old_parent = $child->parent // undef;

	return $child if $old_parent and $old_parent eq $new_parent;
	
	ERROR_CHECKS: {
		#ensures that the selected $new_parent is a type that can adopt
		return carp sprintf "WARNING set_parent error: %s \"%s\" is not a valid parent\n",
			ref $new_parent, $new_parent
			unless $new_parent->can( 'give' );
	}

	$child->$orig( $new_parent );

	# silently fails if the $new_parent fails to adopt the $child
	return unless ref $new_parent->give( $child );
	
	$child->namespace->_clean_cache( $child );

	return $new_parent;
};


# gives this object to its new $namespace reference
around 'set_namespace' => sub {
	my ( $orig, $self, $namespace ) = @_;

	$namespace->give( $self );

	return $self->$orig( $namespace );
};


sub to_address {
	my $wrapper = shift;

	my $address = "$wrapper/target";
	$address = "$wrapper/$address" while $wrapper->parent and $wrapper = $wrapper->parent;
	
	$address = "$wrapper->{namespace}:$address";
	
	return $address;
}


sub _equals {
	my ( $self, $other ) = @_;
	return $self->address eq $other->address
}


1;