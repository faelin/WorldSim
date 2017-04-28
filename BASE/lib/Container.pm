package Container;
use 5.010;

use Moose::Role;
use Carp;
 
no warnings 'experimental::smartmatch';

use Pool;
use Flow;

with 'Wrapper';


# DO NOT ACCESS -> for internal use only!
#	organized by { Name => Pool }
has 'pools' => ( traits  => ['Hash'], is  => 'ro', isa => 'HashRef[Pool]',
    handles => {
		_set_pool	=> 'set',
		_kill_pool	=> 'delete',
		_has_pool	=> 'defined',
		_get_pool	=> 'get',
		_pool_keys	=> 'keys',
		_pool_vals	=> 'values',
		_pool_count	=> 'count',
		_pool_pairs	=> 'kv',
    },
);


# DO NOT ACCESS -> for internal use only!
#	organized by { Name => Flow }
has 'flows' => ( traits  => ['Hash'], is  => 'ro', isa => 'HashRef[Flow]',
    handles => {
		_set_flow	=> 'set',
		_kill_flow	=> 'delete',
		_has_flow	=> 'defined',
		_get_flow	=> 'get',
		_flow_keys	=> 'keys',
		_flow_vals	=> 'values',
		_flow_count	=> 'count',
		_flow_pairs	=> 'kv',
    },
);


# used to adopt a child object into a parent container
#	allows consecutive arguments for adding multiple elements in one line
sub set_child {
	my $parent = shift;
	
	# loop over all consecutive arguments and add each one to the parent container
	$parent->give( $_ ) for @_;

	return $parent;
};


# returns a reference to the query if it is owned by this container
sub get {
	my ( $parent, $child ) = @_;

	for ( ref $child ) {
		return $parent->_get_region		( $child )	when 'Region';
		return $parent->_get_flow		( $child )	when 'Flow';
		return $parent->_get_pool		( $child )	when 'Pool';
		default { return inner( $child ) };
	}
};


# adopts the child into the container using the appropriate HashRef for each child
#	disowns the child from its previous parent
#	updates the namespace attribute
sub give {
	my ( $parent, $child, ) = @_;

	ERROR_CHECKS: {
			return carp sprintf "WARNING container error: failed to adopt %s \"%s\" into %s \"%s\"\n",
			ref $child, $child, ref $parent, $parent
			if $parent->adoption_error( $child );
	}

	$child->set_parent( $parent );

	# selects the appropriate method to add this object to its parent's hash
	for ( ref $child ) {
		$parent->_set_region	( $child => $child )	when 'Region';
		$parent->_set_flow		( $child => $child )	when 'Flow';
		$parent->_set_pool		( $child => $child )	when 'Pool';
		default { inner( $child => $child ) };
	}

	DEBUG_OUTPUT:{
		printf STDERR "      adopted  %-15s  into   %s\n", 
			$child, $parent
			if $main::verbose < 5 and ref $child ne 'Command';
	}
	
	# updates the $child's namespace to match the $parent's
	for ( $parent->namespace ) {
		$child->set_namespace( $_ );
	}

	return $child;
};


# DO NOT ACCESS -> for internal use only!
#	removes the supplied object from the appropriate hash of its parent container
sub disown {
	my ( $parent, $child ) = @_;
	
	# selects the appropriate method to remove this object from the parent's hash
	for ( ref $child ) {
		$parent->_kill_region	( $child )	when 'Region';
		$parent->_kill_flow		( $child )	when 'Flow';
		$parent->_kill_pool		( $child )	when 'Pool';
		$parent->_kill_command	( $child )	when 'Command';
		$parent->_kill_event	( $child )	when 'Event';
		default { inner( $child ) };
	}
	
	DEBUG_OUTPUT: {
		printf STDERR "      removed  %-15s  from   %s\n",
			$child, $parent
			if $main::verbose < 5;
	}
	
	return $child;
};


sub adoption_error {
	my ( $parent, $child ) = @_;
	
	return carp "WARNING adoption error: region \"$child\" cannot be adopted by non-region \"$parent\""
		if ref $child eq 'Region' and ref $parent ne 'Region';
		#	 if the child is a region and the parent is not

	return carp sprintf "WARNING adoption error: parent \"%s\" already has a %s named \"%s\"",
		$parent, ref $child, $child
		if $parent->_has_region( $child );
		#	if there is an object with the child's name already in parent

	return carp "WARNING adoption error: \"$child\" cannot adopt itself"
		if $parent eq $child;
		#	if child is trying to adopt itself

	# checks for recursive adoptioption ("child" cannot be a grandparent of "parent")
	while ( my $grandparent = $parent->parent ) {
		return carp "WARNING adoption error: recursive adoption not allowed (\"$parent\" cannot adopt its ancestor \"$child\")"
			if $grandparent eq $child;
		$parent = $grandparent;	# progress to deeper layer until no more parents are found
	}

	return;
};


1;