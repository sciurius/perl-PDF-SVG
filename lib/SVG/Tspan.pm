#! perl

use v5.26;
use Object::Pad;
use utf8;
use Carp;

class SVG::Tspan :isa(SVG::Element);

method process () {
    my $atts  = $self->atts;
    my $xo    = $self->xo;
    return if $atts->{omit};	# for testing/debugging.

    my ( $x, $y, $dx, $dy ) =
      $self->get_params( $atts, qw( x:U y:U dx:s dy:s ) );
    my $style = $self->style;

    # Scale dx/dy to font size, if using em units.
    $style->{'font-size'} = $self->u($style->{'font-size'});
    if ( $dx =~ /^([.\d]+)em$/ ) {
	$dx = $1 * $style->{'font-size'};
    }
    else {
	$dx = $self->u($dx||0);
    }
    if ( $dy =~ /^([.\d]+)em$/ ) {
	$dy = $1 * $style->{'font-size'};
    }
    else {
	$dy = $self->u($dy||0);
    }

    my $text = "";

    my $color = $style->{color};
    my $anchor = $style->{'text-anchor'} || "left";

    $self->_dbg( $self->name, " ",
		 defined($atts->{x}) ? ( " x=$x" ) : (),
		 defined($atts->{y}) ? ( " y=$y" ) : (),
		 defined($atts->{dx}) ? ( " dx=$dx" ) : (),
		 defined($atts->{dy}) ? ( " dy=$dy" ) : (),
		 defined($style->{"text-anchor"})
		 ? ( " anchor=\"$anchor\"" ) : (),
	       );

    my @c = $self->get_children;

    if ( $color ) {
	$xo->fill_color($color);
    }

    {
	my $x = $dx + $x;
	my $y = - $dy - $y;

	my %o = ();
	$o{align} = $anchor eq "end"
	  ? "right"
	  : $anchor eq "middle" ? "center" : "left";

	if ( 0 && $x && !$y && $o{align} eq "left" ) {
	    $o{indent} = $x;
	    $self->_dbg( "txt indent %.2f", $x );
	}
	elsif ( $x || $y ) {
	    $self->_dbg( "txt translate( %.2f, %.2f )", $x, $y );
	}

	for my $c ( @c ) {
	    $self->_dbg( "+ xo save" );
	    $xo->save;
	    $xo->transform( translate => [ $x, $y ] );
	    if ( ref($c) eq 'SVG::TextElement' ) {
		$xo->textstart;
		$xo->font( $self->makefont($style));
		$x += $xo->text( $c->content, %o );
		$xo->textend;
	    }
	    elsif ( ref($c) eq 'SVG::Tspan' ) {
		my ( $x0, $y0 ) = $c->process;
		$x += $x0; $y += $y0;
		$self->_dbg("tspan moved to $x, $y");
	    }
	    $self->_dbg( "- xo restore" );
	    $xo->restore;
	}

	$self->css_pop;
	return wantarray ? ( $x, $y ) : $x;

    }
}

1;
