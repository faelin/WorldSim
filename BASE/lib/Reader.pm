package Reader;
use 5.010;
use warnings;
use strict;

my $file = shift @ARGV;


my $LBRACE  = qr#\(|\{|\[|\<#;
my $RBRACE  = qr#\)|\}|\]|\>#;

my $SIGIL  = qr#\$|@|%#;
my $VARNAME = qr#$SIGIL+[\w\$]*#;

my $DELIM  = qr#\s*\W#;
my $DQUOTE  = qr#"#;
my $SQUOTE  = qr#'#;
my $OPQUOTE = qr#(?<!/|\B)(tr|[msy]|q[qwxr])(?<delim>$DELIM)#;
my $TOHERE  = qr#<<((")|('))?(?<delim>\w+)((?(2)")|(?(3)'));#;
my $COMMENT = qr/#/;
my $QUOTISH = qr#($DQUOTE|$SQUOTE|$OPQUOTE|$TOHERE|$COMMENT)#;

sub read {
	my $fh = shift;
	open READFILE, "<", $fh
		or die "Could not open file <$fh>: $!";
	&tokenize( <READFILE> );
}


sub tokenize {
	s#[\s]+# #g and s#\A ##g for @_;

	my @token_stack;
	my $quote = undef;
	my $delim = '';
	my $merge = '';
	
	LINE: for ( my $line = $merge . shift @_ ) {
		$quote = undef if $quote eq 'COMMENT';

		while /\G($DQUOTE|$SQUOTE)/pg {
			if ( $quote eq $1 ) {
				push @token_stack => ${^PREMATCH} . $1;
				$quote = undef;
				$merge = '';
			} elsif ( $quote ~~ undef ) {
				$quote = 'DQUOTE' if $1 = q/"/;
				$quote = 'SQUOTE' if $1 = q/'/;
			}
		}
		
		while /\G($OPQUOTE)/ {
			if
		}
		
		while /\G(?<quote>$QUOTISH)/g {
			$quote = undef	if $1 =~ $DQUOTE and $quote ~~ ( 'DQUOTE', undef );
			$quote = undef	if $1 =~ $SQUOTE and $quote ~~ ( 'SQUOTE', undef );
			$quote = undef if $1 =~ $OPQUOTE and $quote ~~ ( 'OPQUOTE', undef );
			$quote = undef	if $1 =~ $COMMENT and $quote ~~ ( 'COMMENT', undef );
			$delim = $+{delim} // undef;
		}

		push @braces => $1 while m/\G$LBRACE/g;
		while ( /\G$RBRACE/g ) {
			pop @braces
				if $braces[-1] eq $1 =~ tr# \} \) \] \> # \{ \( \[ \< #
				or die "Reader (parse) error at $fh line $., near \"$line\" \n $!"
		}
	}

	printf " %s\n" x @lines, @lines;
}


&read( "test.pl" );