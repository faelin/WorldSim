package Namespace;
use 5.010;

use Moose;
use Carp;
use Storable;
use overload
	'""' => sub { shift->name },
	fallback => 1;
use Timeline;
use Region;

no warnings 'experimental::smartmatch';


# see Carp doc for info
$Carp::Internal{$_}++ for qw{ Class::MOP Class::MOP::Attribute Class::MOP::Class Class::MOP::Method::Wrapped
	Wrapper Timeline Event Address Command Pool Flow Container Region };

# debug output to confirm creation
around BUILDARGS => sub {
	my ( $orig, $self, %args ) = @_;
	
	ERROR_CHECKS: {
		return carp "WARNING Namespace error: cannot overwrite namespace \"$args{ 'name' }\""
			if $main::spaces{ "$args{ 'name' }" };
	}
	
	return $self->$orig( %args );
};


sub BUILD {
	my $self = shift;

	DEBUG_OUTPUT: {
		printf STDERR "New namespace \"%s\" created with id %s\n",
			$self, $self->id
			if $main::verbose < 1.5;
	}

	$main::spaces{ $self } = $self;

	#	TODO: buffering
	#$main::buffer{ $self } = [];
	#open SAVETEST, '>', ".\\data\\buffer\\buffer_$self.txt" or die "Could not open savetest: $!";

	$self->set_ticker( Timeline->new( name => "ticker|$self", ns => $self ) ) unless $self->ticker;
	# builds default timeline is none is provided.
	
	return $self;
}


has 'name' => ( is => 'rw', isa => 'Str', writer => 'set_name', default => 'MAIN', );	# string identifier for the Namespace
has 'id' => ( is  => 'ro', isa => 'Str', writer => '_update_id', default => '000000', );	# provides unique IDs to objects in this namespace
has 'ticker' => ( is => 'ro', isa => 'Timeline', writer => 'set_ticker' );	# timeline for this Namespace
has 'seed' => ( is => 'ro', isa => 'Int', writer => 'set_seed', default => srand );	# ensures consistently random events

after 'set_ticker' => sub{ my $ns = shift; $ns->ticker->set_namespace( $ns ) unless $ns->ticker->namespace->name eq $ns->name };


# DO NOT ACCESS -> for internal use only!
sub give {
	my ( $self, $new_obj ) = @_;
	
	return $new_obj if $self->owns( $new_obj );
	#	returns silently if $new_obj is already in this namespace
	
	$new_obj->namespace->take( $new_obj );
	#	removes $new_obj from its current namespace
	
	my $id = $self->id;
	$self->_update_id( ++$id );

	$new_obj->set_id( $id );
	#	sets the id attribute in $new_obj

	# pushes new_obj into the correct HashRef with the current id as the key
	for (ref $new_obj) {
		$self->_add_pool	( $id => $new_obj ) when 'Pool';
		$self->_add_flow	( $id => $new_obj ) when 'Flow';
		$self->_add_region	( $id => $new_obj ) when 'Region';
		$self->_add_tline	( $id => $new_obj ) when 'Timeline';
		$self->_add_event	( $id => $new_obj ) when 'Event';
		default { inner( $id => $new_obj ) }
	}
	
	DEBUG_OUTPUT: {
		printf STDERR "%-8s %-15s  spawned in namespace  %6s  with id %s\n",
			ref $new_obj, $new_obj, $self, $id
			if $main::verbose < 2.5;
	}

	return $new_obj;
};


# DO NOT ACCESS -> for internal use only!
sub take {
	my ( $self, $old_obj ) = @_;
	
	return unless defined $old_obj->id;

	# removes $old_obj from the appropriate HashRef in its namespace
	for (ref $old_obj) {
		$old_obj->namespace->_kill_pool		( $old_obj->id ) when 'Pool';
		$old_obj->namespace->_kill_flow		( $old_obj->id ) when 'Flow';
		$old_obj->namespace->_kill_region	( $old_obj->id ) when 'Region';
		$old_obj->namespace->_kill_tline	( $old_obj->id ) when 'Timeline';
		$old_obj->namespace->_kill_event	( $old_obj->id ) when 'Event';
		default { inner( $old_obj ) }
	}
	
	DEBUG_OUTPUT: {
		printf STDERR "%-8s %-15s  despawned from namespace  %6s  (id %s)\n",
			ref $old_obj, $old_obj, $old_obj->namespace, $old_obj->id
			if $main::verbose < 2;
	}

	$self->_clean_cache( $old_obj );
	#	removes $old_obj from the cache in its namespace
	
	return $self;
}


sub owns {
	my ( $self, $obj ) = @_;

	for ( ref $obj ) {
		return $self->_has_pool		( $obj ) when 'Pool';
		return $self->_has_flow		( $obj ) when 'Flow';
		return $self->_has_region	( $obj ) when 'Region';
		return $self->_has_tline	( $obj ) when 'Timeline';
		return $self->_has_event	( $obj ) when 'Event';
		default { inner( $obj ) }
	}
}


# organized by { ID => object }
has 'pools' => ( traits  => ['Hash'], is  => 'ro', isa => 'HashRef[Pool]',
    handles => {
		_add_pool		=> 'set',
		_kill_pool		=> 'delete',
		_has_pool		=> 'defined',
		_get_pool		=> 'get',
		_pool_keys		=> 'keys',
		_pool_vals		=> 'values',
		_no_pools		=> 'is_empty',
		_pool_count		=> 'count',
		_pool_pairs		=> 'kv',
    },
);

# organized by { ID => object }
has 'flows' => ( traits  => ['Hash'], is  => 'ro', isa => 'HashRef[Flow]',
    handles => {
		_add_flow		=> 'set',
		_kill_flow		=> 'delete',
		_has_flow		=> 'defined',
		_get_flow		=> 'get',
		_flow_keys		=> 'keys',
		_flow_vals		=> 'values',
		_no_flows		=> 'is_empty',
		_flow_count		=> 'count',
		_flow_pairs		=> 'kv',
    },
);

# organized by { ID => object }
has 'regions' => ( traits  => ['Hash'], is  => 'ro',  isa => 'HashRef[Region]',
    handles => {
		_add_region		=> 'set',
		_kill_region	=> 'delete',
		_has_region		=> 'defined',
		_get_region		=> 'get',
		_region_keys	=> 'keys',
		_region_vals	=> 'values',
		_no_regions		=> 'is_empty',
		_region_count	=> 'count',
		_region_pairs	=> 'kv',
    },
);

# organized by { ID => object }
has 'timelines' => ( traits  => ['Hash'],  is  => 'ro', isa => 'HashRef[Timeline]',
    handles => {
		_add_tline	=> 'set',
		_kill_tline	=> 'delete',
		_has_tline	=> 'defined',
		_get_tline	=> 'get',
		_tline_keys	=> 'keys',
		_tline_vals	=> 'values',
		_no_tline	=> 'is_empty',
		_tline_count	=> 'count',
		_tline_pairs	=> 'kv',
    },
);

# organized by { ID => object }
has 'events' => ( traits  => ['Hash'], is  => 'ro', isa => 'HashRef[Event]',
    handles => {
		_add_event		=> 'set',
		_kill_event		=> 'delete',
		_has_event		=> 'defined',
		_get_event		=> 'get',
		_event_keys		=> 'keys',
		_event_vals		=> 'values',
		_no_events		=> 'is_empty',
		_event_count	=> 'count',
		_event_pairs	=> 'kv',
    },
);

# organized by { ID => object }
has 'miscs' => ( traits  => ['Hash'], is  => 'ro', isa => 'HashRef[IsWrapper]',
    handles => {
		_add_misc		=> 'set',
		_kill_misc		=> 'delete',
		_has_misc		=> 'defined',
		_get_misc		=> 'get',
		_misc_keys		=> 'keys',
		_misc_vals		=> 'values',
		_no_misc		=> 'is_empty',
		_misc_count		=> 'count',
		_misc_pairs		=> 'kv',
    },
);

# organized by { Address => Region } or { Name => Region[] }
has 'cache' => ( traits  => ['Hash'], is  => 'ro', isa => 'HashRef',
    handles => {
		_add_cache		=> 'set',
		_kill_cache		=> 'delete',
		_has_cache		=> 'defined',
		_get_cache		=> 'get',
		_cache_keys		=> 'keys',
		_cache_vals		=> 'values',
		_no_caches		=> 'is_empty',
		_cache_count	=> 'count',
		_cache_pairs	=> 'kv',
    },
);


sub wrappers {
	return (
		$_->_pool_vals,
		$_->_flow_vals,
		$_->_region_vals,
		$_->_tline_vals,
		$_->_event_vals,
		$_->_misc_vals,
	) for @_;
}


sub containers { return (	$_->_region_vals, ) for @_ }


# removes the provided $obj from the cache
#	or fails silently
sub _clean_cache {
	my ( $self, $obj ) = @_;
	my ($key, $val);
	
	while ( ( $key, $val ) = $self->_cache_pairs ) {
		$self->_kill_cache( $key ) and $obj->kill_address if $obj ~~ $val
		#	removes $obj from the cache if it matches a value in the cache
		#		and resets the address of the $obj
	}
}


sub search {
	my ( $self, $address ) = @_;
	my ( @tree, @possible, $grandparent, $parent, $child, $found );
	
	return $self->_get_cache( $address ) if $address ~~ $self->cache;
	# returns the cached reference for $address if it exists

	@tree = split '/' => $address => -1;	# creates a list of the addressed references
	pop @tree;	# removes the "target" reference from the end of the address string
	$grandparent = shift @tree // return undef;	# retrieves the grandparent name from @tree
	# returns undef to represent creation of the target in a void context if no grandparent is present
	
	# my @test = $self->_cache_vals;
	# say "TEST" unless @test;
	
	# pulls the cached array of possible references for $grandparent if it exists
	unless ( @possible = grep{ $grandparent eq $_ } $self->_cache_vals ) {
		
		return carp "WARNING search error: parent \"$grandparent\" not found in namespace \"$self->{name}\""
			unless @possible = grep{ $grandparent eq $_ } $self->containers;
			# pulls all $self->containers that match $grandparent
			#	or aborts the retrieval if $grandparent was not found in this namespace

		$self->_add_cache( $grandparent => \@possible );
		#	caches the updated list of @possible regions for $grandparent
	}

	# traverses the adoption tree for each region in @possible to see if it matches the given address
	POSSIBLE: for $parent ( @possible ) {
		TREE: for $child ( @tree ) {
			next POSSIBLE unless $parent->_has_region( $child );	# checks the next @possible grandparent if a discrepency is found
			$parent = $parent->_get_region( $child );		# progresses along the adoption tree as per the given address
		}
		
		return carp "WARNING search error: ambiguous address \"$address\"" if $found;
		#	aborts the retrieval if more than one region matches the given address
		
		$found = $parent;	# $parent is now the grandchild reference
	}

	return carp "WARNING search error: invalid address \"$address\"" unless $found;
	#	aborts if no $parent is found that matches the given address
	
	$self->_add_cache( $address => $found );	# caches the newly retrieved address
	
	return $found;
}


# advances this namespace's ticker by 1 day, and returns this namespace
sub tick { return shift->ticker->advance( shift )->namespace }


# prints the list of objects owned by this namespace
#	in the format (class, name, id)
sub list_children {
	my $self = shift;
	
	my @objects_list = map { ref $_, $_, $_->id } sort { $a->id ge $b->id } $self->wrappers;
	sprintf "List of objects in $self:\n" .
			"\t %8s  %-15s  %s \n" x ( @objects_list / 3 ),
			@objects_list;
}


1;
__PACKAGE__->meta->make_immutable;