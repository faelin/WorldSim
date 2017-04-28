package Region;
use 5.010;

use Moose;
use overload
	'~~' => sub { shift eq shift },
	fallback => 1;

with 'Container';


# applies default value for 'name' attribute - overridden by user-supplied value
around BUILDARGS => sub {
	my ($orig, $self, %args) = @_;

	$args{ 'name' } = $args{ 'name' } // "UNNAMED";

	return $self->$orig(%args);
};


# DO NOT ACCESS -> for internal use only!
#	list of child regions owned by this region, organized by { Name => Region }
has 'subregions' => ( traits  => ['Hash'], is  => 'ro', isa => 'HashRef[Region]',
    handles => {
		_set_region		=> 'set',
		_kill_region	=> 'delete',
		_has_region		=> 'defined',
		_get_region		=> 'get',
		_region_keys	=> 'keys',
		_region_vals	=> 'values',
		_region_count	=> 'count',
		_region_pairs	=> 'kv',
    },
);


1;
__PACKAGE__->meta->make_immutable;