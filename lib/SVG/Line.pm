#! perl

use v5.26;
use Object::Pad;
use utf8;
use Carp;

class SVG::Line :isa(SVG::Element);

method process () {
    my $atts = $self->atts;
    my $xo   = $self->xo;
    return if $atts->{omit};	# for testing/debugging.

    my ( $x1, $y1, $x2, $y2 ) =
      $self->get_params( $atts, qw( x1:U y1:U x2:U y2:U ) );

    $self->_dbg( $self->getElementName, " x1=$x1 y1=$y1 x2=$x2 y2=$y2" );
    $self->_dbg( "+ xo save" );
    $xo->save;

    $self->set_graphics;

    $xo->move( $x1, -$y1 );
    $xo->line( $x2, -$y2 );
    $self->_paintsub->();

    $self->_dbg( "- xo restore" );
    $xo->restore;
    $self->css_pop;
}


1;
