package Timeline;
use 5.010;

use constant {
	DAY_SEC		=>	86400,
	HOUR_SEC	=>	3600,
	DAY_HOUR	=>	24,
};

use Moose;
use Carp;
use overload
	'0+'	=> sub { shift->date },
	'+='	=> 'advance',
	'-=' 	=> 'rewind',
	fallback => 1;

use Event;

with 'Wrapper' => { -excludes => [ 'parent' ] };

sub BUILD {
	my $self = shift;

	$self->name = "$self->{name}|$self->{namespace}"
		if not $self->name =~ /|/;
	
	return $self->namespace->give( $self );
}


after 'set_namespace' => sub {
	my $self = shift;
	
	$self->set_name( "$self->{name}|$self->{namespace}" )
		unless $self->name =~ /\A\w+|\w+\Z/;
	
	return $self;
};


# date in seconds
has 'date' => ( is => 'ro', isa => 'Int', writer => 'set_date', default => 0, );


# HashRef of the events available to this timeline:
#	organized by { timestamp => Event }
has 'events' => ( traits  => ['Hash'], is  => 'ro', isa => 'HashRef[Event]',
    handles => {
		_set_event		=> 'set',
		_kill_event		=> 'delete',
		_has_event		=> 'defined',
		_get_event		=> 'get',
		_event_count	=> 'count',
		_event_vals		=> 'values',
		_event_keys		=> 'keys',
		_event_pairs	=> 'kv',
    },
);


# used for error checking
around '_set_event' => sub {
	my ( $orig, $self, $date, $event ) = @_;
	
	ERROR_CHECKS: {
		return carp "WARNING set_timeline error: date required for \"$event\""
			unless defined $date;
		return carp "WARNING set_timeline error: date or event required for \"$date\""
			unless defined $event;
	}
	
	DEBUG_OUTPUT:{
			printf STDERR "      set  %-15s  at  %s  in   %s\n",
				$event, $date, $self
				if $main::verbose < 3;
	}
		
	return $self->$orig( $date => $event );
};


# advance by $amount of hours
#	with optional period of updates, $incr, in hours
sub advance {
	my ( $self, $amount, $incr ) = @_;
	my ( $new_date, @times );

	$incr = abs( $incr // 1 );
	$amount = ( $amount // 24 ) / 24;	# convert $amount into days, defaults to 1 day
	$new_date = $self->date + $amount*DAY_SEC;	# $new_date = current date plus $amount in seconds

	return $self->rewind( $amount ) if $amount < 0;	# cannot advance by negative number

	@times = ($incr*$self->date/HOUR_SEC .. $incr*$new_date/HOUR_SEC),
				grep { $_ if $_ > $self->date and $_ <= $new_date } $self->_event_keys;
				#	list of all events between the current date and the $new_date,
				#		merged with periodic times at intervals determined by $incr
	last if ( @times = sort { $a <=> $b } @times ) < 2;

	TIME: for ( my $i = 0; $i < @times; $i++ ) {
		my $time = ( $i + 1 < @times ? $times[$i + 1] - $times[$i] : 0 );	# $time is determined by the difference between each consecutive timestamp in @times;
		$self->_get_event( $times[$i] )->run if $self->_has_event( $times[$i] );	# runs any event occuring at the specified time
		#	events are run before flows to allow greater user-control
		
		my $count = 0;
		my @flows = $self->namespace->_flow_vals;
		FLOW: while ( my $flow = shift @flows ) {
			if (not defined $flow or @flows < $count++) {
				$flow->send( $time );
				next FLOW;
			}

			# updates pools via flows advanced in time-increments
			#	unless sending would reduce the pool below zero
			unless ( $flow->test_send( $time ) < 0 ) {
				print "\t";
				$flow->send( $time );
				$count = 0;
			} else {
				push @flows => $flow;	# delays sending $flow if its near pool would be drained below 0
			}
		}
	}
	
	$self->set_date( $new_date );

	return $self;
}


sub rewind {
}


# adds events to this timeline in the form of { DateTime => Event }
#	can take multiple events at once
sub give {
	my ( $self, @args ) = @_;

	$self->_set_event( shift @args => shift @args ) while @args;
	#	Timeline->_set_event takes ( date => event )

	return $self;
};


1;
__PACKAGE__->meta->make_immutable;