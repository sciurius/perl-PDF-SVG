#! perl

use v5.26;
use Object::Pad;
use utf8;
class SVGPDF::Element;

use Carp;

field $xo       :mutator;
field $style    :accessor;
field $name     :param :accessor;
field $atts     :param :accessor;
field $css      :accessor;
field $content  :param :accessor;	# array of children
field $root     :param :accessor;	# top module

BUILD {
    $css  = $root->css;
    $xo   = $root->xoforms->[-1]->{xo};
};

method _dbg (@args) {
    $root->_dbg(@args);
}

method css_push ( $updated_atts = undef ) {
    $style = $css->push( element => $name, %{$updated_atts // $atts} );
}

method css_pop () {
    $css->pop;
}

method set_transform ( $tf ) {
    return unless $tf;

    my $nooptimize = 1;
    $tf =~ s/\s+/ /g;

    # The parts of the transform need to be executed in order.
    while ( $tf =~ /\S/ ) {
	if ( $tf =~ /^\s*translate\s*\((.*?)\)(.*)/ ) {
	    $tf = $2;
	    my ( $x, $y ) = $self->getargs($1);
	    $y ||= 0;
	    if ( $nooptimize || $x || $y ) {
		$xo->transform( translate => [ $x, -$y ] );
		$self->_dbg( "transform translate(%.2f,%.2f)", $x, -$y );
	    }
	}
	elsif ( $tf =~ /^\s*rotate\s*\((.*?)\)(.*)/ ) {
	    $tf = $2;
	    my ( $r, $x, $y ) = $self->getargs($1);
	    if ( $nooptimize || $r ) {
		if ( $x || $y ) {
		    $xo->transform( translate => [ $x, -$y ] );
		    $self->_dbg( "transform translate(%.2f,%.2f)", $x, -$y );
		}
		$self->_dbg( "transform rotate(%.2f)", $r );
		$xo->transform( rotate => -$r );
		if ( $x || $y ) {
		    $xo->transform( translate => [ -$x, $y ] );
		    $self->_dbg( "transform translate(%.2f,%.2f)", -$x, $y );
		}
	    }
	}
	elsif ( $tf =~ /^\s*scale\s*\((.*?)\)(.*)/ ) {
	    $tf = $2;
	    my ( $x, $y ) = $self->getargs($1);
	    $y ||= $x;
	    if ( $nooptimize || $x != 1 && $y != 1 ) {
		$self->_dbg( "transform scale(%.2f,%.2f)", $x, $y );
		$xo->transform( scale => [ $x, $y ] );
	    }
	}
	elsif ( $tf =~ /^\s*matrix\s*\((.*?)\)(.*)/ ) {
	    $tf = $2;
	    my ( @m ) = $self->getargs($1);
	    $self->nfi("matrix transformations")
	      unless abs($m[0]) == 1 && abs($m[3]) == 1
	             && !abs($m[1]) && !abs($m[2]) && !abs($m[4]) && !abs($m[5]);
	    # We probably have to flip some elements...
	    $self->_dbg( "transform matrix(%.2f,%.2f %.2f,%.2f %.2f,%.2f)", @m);
	    $xo->transform( matrix => \@m );
	}
	elsif ( $tf =~ /^\s*skew([XY])\s*\((.*?)\)(.*)/i ) {
	    $tf = $3;
	    my ( $x ) = $self->getargs($2);
	    my $y = 0;
	    if ( $1 eq "X" ) {
		$y = -$x;
		$x = 0;
	    }
	    else {
		$x = -$x;
		$y = 0;
	    }
	    $self->_dbg( "transform skew(%.2f %.2f)", $x, $y );
	    $xo->transform( skew => [ $x, $y ] );
	}
	else {
	    warn("Ignoring transform: $tf");
	    $self->_dbg("Ignoring transform: \"$tf\"");
	    $tf = "";
	}
    }
}

method set_graphics () {

    my $msg = $name;

    if ( defined( my $lw = $style->{'stroke-width'} ) ) {
	$msg .= " stroke-width=$lw";
	$xo->line_width($self->u($lw));
    }

    if ( defined( my $linecap = $style->{'stroke-linecap'} ) ) {
	$linecap = lc($linecap);
	if    ( $linecap eq "round"  ) { $linecap = 1 }
	elsif ( $linecap eq "r"      ) { $linecap = 1 }
	elsif ( $linecap eq "square" ) { $linecap = 2 }
	elsif ( $linecap eq "s"      ) { $linecap = 2 }
	else                           { $linecap = 0 } # b butt
	$msg .= " linecap=$linecap";
	$xo->line_cap($linecap);
    }

    if ( defined( my $linejoin = $style->{'stroke-linejoin'} ) ) {
	$linejoin = lc($linejoin);
	if    ( $linejoin eq "round" ) { $linejoin = 1 }
	elsif ( $linejoin eq "r"     ) { $linejoin = 1 }
	elsif ( $linejoin eq "bevel" ) { $linejoin = 2 }
	elsif ( $linejoin eq "b"     ) { $linejoin = 2 }
	else                           { $linejoin = 0 } # m miter
	$msg .= " linejoin=$linejoin";
	$xo->line_join($linejoin);
    }

    my $color = $style->{color};
    my $stroke = $style->{stroke};
    if ( lc($stroke) eq "currentcolor" ) {
	# Nothing. Use current.
	$msg .= " stroke=(current)";
	$stroke = $color;
    }
    if ( $stroke ne "none" ) {
	$stroke =~ s/\s+//g;
	if ( $stroke =~ /rgb\(([\d.]+)%,([\d.]+)%,([\d.]+)%\)/ ) {
	    $stroke = sprintf("#%02X%02X%02X",
			      map { $_*2.55 } $1, $2, $3);
	}
	elsif ( $stroke =~ /rgb\(([\d.]+),([\d.]+),([\d.]+)\)/ ) {
	    $stroke = sprintf("#%02X%02X%02X", $1, $2, $3);
	}
	$xo->stroke_color($stroke);
	$msg .= " stroke=$stroke";
    }
    else {
	$msg .= " stroke=none";
    }

    my $fill = $style->{fill};
    if ( lc($fill) eq "currentcolor" ) {
	# Nothing. Use current.
	$msg .= " fill=(current)";
	$fill = $color;
    }
    if ( lc($fill) ne "none" && $fill ne "transparent" ) {
	$fill =~ s/\s+//g;
	if ( $fill =~ /rgb\(([\d.]+)%,([\d.]+)%,([\d.]+)%\)/ ) {
	    $fill = sprintf("#%02X%02X%02X",
			    map { $_*2.55 } $1, $2, $3);
	}
	elsif ( $fill =~ /rgb\(([\d.]+),([\d.]+),([\d.]+)\)/ ) {
	    $fill = sprintf("#%02X%02X%02X", $1, $2, $3);
	}
	$xo->fill_color($fill);
	$msg .= " fill=$fill";
    }
    else {
	$msg .= " fill=none";
    }

    if ( my $sda = $style->{'stroke-dasharray'}  ) {
	my @sda;
	if ( $sda && $sda ne "none" ) {
	    $sda =~ s/,/ /g;
	    @sda = split( ' ', $sda );
	}
	$msg .= " sda=@sda";
	$xo->line_dash_pattern(@sda);
    }

    $self->_dbg($msg);
    return $style;
}

# Return a stroke/fill/paint sub depending on the fill stroke styles.
method _paintsub () {
    if ( $style->{stroke}
	 && $style->{stroke} ne 'none'
	 && $style->{stroke} ne 'transparent'
	 # Hmm. Saw a note somewhere that it defaults to 0 but other notes
	 # say that it should be 1px...
	 && $style->{'stroke-width'}//1 != 0
       ) {
	if ( $style->{fill}
	     && $style->{fill} ne 'none'
	     && $style->{fill} ne 'transparent'
	   ) {
	    return sub {
		$self->_dbg("xo paint (",
			    join(" ", $style->{stroke}, $style->{fill} ), ")");
		$xo->paint;
	    };
	}
	else {
	    return sub {
		$self->_dbg("xo stroke (", $style->{stroke}, ")");
		$xo->stroke;
	    };
	}
    }
    elsif ( $style->{fill}
	    && $style->{fill} ne 'none'
	    && $style->{fill} ne 'transparent'
	  ) {
	return sub {
	    $self->_dbg("xo fill (", $style->{stroke}, ")");
	    $xo->fill;
	};
    }
    else {
	return sub {};
    }
}

method process () {
    # Unless overridden in a subclass there's not much we can do.
    state $warned = { desc => 1, title => 1, metadata => 1 };
    warn("SVG: Skipping element \"$name\" (not implemented)\n")
      unless $warned->{$name}++;;
    $self->_dbg("skipping $name (not implemented)");
    # $self->traverse;
}

method get_children () {

    # Note: This is the only place where these objects are created.

    my @res;
    for my $e ( @{$self->content} ) {
	if ( $e->{type} eq 'e' ) {
	    my $pkg = "SVGPDF::" . ucfirst(lc $e->{name});
	    $pkg = "SVGPDF::Element" unless $pkg->can("process");
	    push( @res, $pkg->new
		  ( name    => $e->{name},
		    atts    => { map { lc($_) => $e->{attrib}->{$_} } keys %{$e->{attrib}} },
		    content => $e->{content},
		    root    => $self->root,
		  ) );
	}
	elsif ( $e->{type} eq 't' ) {
	    push( @res, SVGPDF::TextElement->new
		  ( content => $e->{content},
		  ) );
	}
	else {
	    # Basically a 'cannot happen',
	    croak("Unhandled node type ", $e->{type});
	}
    }
    return @res;
}

method traverse () {
    for my $c ( $self->get_children ) {
	next if ref($c) eq "SVGPDF::TextElement";
	$self->_dbg("+ start handling ", $c->name, " (", ref($c), ")");
	$c->process;
	$self->_dbg("- end handling ", $c->name);
    }
}

method u ( $a ) {
    confess("Undef in units") unless defined $a;
    return undef unless $a =~ /^([-+]?[\d.]+)(.*)$/;
    return $1 if $2 eq "" || $2 eq "pt" || $2 eq "deg";
    return $1 if $2 eq "px";	# approx
    return $1*12 if $2 eq "em";	# approx
    return $1*10 if $2 eq "ex";	# approx
    return $1*72/2.54 if $2 eq "cm";
    return $1*72/25.4 if $2 eq "mm";
    return $1;			# will hopefully crash somewhere...
}

method getargs ( $a ) {
    confess("Null attr?") unless defined $a;
    $a =~ s/^\s+//;
    $a =~ s/\s+$//;
    map { $self->u($_) } split( /\s*[,\s]\s*/, $a );
}

# Initial fiddling with entity attributes.
method get_params ( @desc ) {
    my $atts = shift(@desc) if ref($desc[0]) eq 'HASH';
    my @res;
    my %atts = %{ $atts // $self->atts }; # copy

    # xlink:href is obsoleted in favour of href.
    $atts{href} //= delete $atts{"xlink:href"} if exists $atts{"xlink:href"};

    for my $param ( @desc ) {

	# Attribute may be followed by ':' and flags.
	# 0   undef -> 0
	# h   process units, % is viewBox height
	# s   undef -> ""
	# u   process units
	# v   process units, % is viewBox width
	# U   undef -> 0, process units
	# !   barf if undef
	my $flags = "";
	( $param, $flags ) = ( $1, $2 )
	  if $param =~ /^(.*):(.*)$/;
	$param = lc($param);

	# Get and remove the attribute.
	my $p = delete( $atts{$param} );

	unless ( defined $p ) {
	    if    ( $flags =~ /s/ )    { $p = ""; }
	    elsif ( $flags =~ /[0U]/ ) { $p = 0;  }
	    else {
		croak("Undefined mandatory attribute: $param")
		  if $flags =~ /\!/;
		push( @res, $p );
		next;
	    }
	}

	$flags = lc($flags);
	# Convert units if 'u' flag.
	if ( $flags =~ /([huv])/ ) {
	    my $flag = $1;
	    if ( $p =~ /^([\d.]+)\%$/ ) {
		$p = $1/100;
		if ( $flags eq "w" || $param =~ /^w(idth)?$/i ) {
		    # Percentage of viewBox width.
		    $p *= $root->xoforms->[-1]->{width};
		}
		elsif ( $flag eq "h" || $param =~ /^h(eight)?$/i ) {
		    # Percentage of viewBox height.
		    $p *= $root->xoforms->[-1]->{height};
		}
		else {
		    # Percentage of viewBox diagonal.
		    $p *= $root->xoforms->[-1]->{diag};
		}
	    }
	    else {
		$p = $self->u($p);
	    }
	}

	push( @res, $p );
    }

    # CSS push with updated attributes.
    $self->css_push( \%atts );

    # Return param values.
    return @res;
}

method get_cdata () {
    my $res = "";
    for ( $self->get_children ) {
	$res .= "\n" . $_->content if ref($_) eq "SVGPDF::TextElement";
    }
    $res;
}

method nfi ( $tag ) {
    state $aw = {};
    warn("SVG: $tag - not fully implemented, expect strange results.\n")
      unless $aw->{$tag}++;
}

################ Bounding Box ################

# method bb ( $x, $y, $t = 0 ) {
#     my $bb = $self->root->xoforms->[-1]->{bb};
#
#     $t = $self->u($t) unless $t =~ /^[-+]?\d*(?:\.\d*)$/;
#     $t /= 2;
#     $bb->[0] = $x-$t if $bb->[0] > $x-$t;
#     $bb->[1] = $y-$t if $bb->[1] > $y-$t;
#     $bb->[2] = $x+$t if $bb->[2] < $x+$t;
#     $bb->[3] = $y+$t if $bb->[3] < $y+$t;
#
#     return $bb;
# }
#

################ TextElement ################

class SVGPDF::TextElement;

field $content  :param :accessor;

# Actually, we should take style->{white-space} into account...
BUILD {
    # Reduce whitespace.
    $content =~ s/\s+/ /g;
}

method process () {
    # Nothing to process.
}

1;
