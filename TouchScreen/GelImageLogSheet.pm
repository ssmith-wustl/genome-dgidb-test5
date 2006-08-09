package TouchScreen::GelImageLogSheet;

# .---------------------------------------------------------------------.
# | Copyright (c) 2002 Craig S. Pohl and Washington University          |
# |                    Genome Sequencing Center. All rights reserved.   |
# |                    email- cpohl@watson.wustl.edu                    |
# |                                                                     |
# |---------------------------------------------------------------------|
# | 1.0 -          |
# |                                                                     |
# `---------------------------------------------------------------------'


$VERSION = "1.0";

#--------------------------------------------------------------------------------------
# Code128 package
#--------------------------------------------------------------------------------------

require Exporter;


our @ISA = qw (Exporter AutoLoader);
our @EXPORT = qw ( );

use GD(1.19);
use strict;
use English;

sub new {

    my ($class, $width, $height) = @_;
    
    my $self = {};

    bless $self, $class;

    if(($height <= 750) && ($width <= 550)) {
	
	# Define the image size for GD
	$self->{'image'} = new GD::Image($width, $height);
	
	return($self);
    }
    
    return undef;
}


sub InsertBarcode {

 #   my ($self, $bar_data, $dstX, $dstY) = @_;
    my ($self, $bar_image, $dstX, $dstY) = @_;

#    my $bar_image = GD::Image->newFromGd($bar_data); 
    
    my ($bar_width,$bar_height) = $bar_image->getBounds();

    $self->{'image'} -> copy($bar_image,$dstX,$dstY,0,0,$bar_width,$bar_height) 
}


sub CreateGelImage {
    
    my ($self, $dstX, $dstY, $width, $height, $num_lanes, $lanes_top, $lanes_bot) = @_;

    my $black = $self->{'image'}->colorAllocate(0,0,0);
    my $fontsize=gdSmallFont;
    
    my $endX = $width + $dstX;
    my $endY = $height+$dstY;
    
    my $lanewidth = $width/$num_lanes;

    $self->{'image'}->rectangle($dstX,$dstY,$endX,$endY,$black);
    
    my $posX = $dstX+($lanewidth/2)-4;
    my $posY = $dstY - 5;
    
    
    if(defined $lanes_top->[0]) {
	foreach my $lane (@{$lanes_top}) {
	    $self->{'image'}->stringUp($fontsize,$posX,$posY,$lane,$black);
	    $posX += $lanewidth;
	}
    }


    $posX = $dstX+($lanewidth/2)-4;
    if(defined $lanes_bot->[0]) {
	foreach my $lane (@{$lanes_bot}) {
	    $self->{'image'}->stringUp($fontsize,$posX,$dstY+$height+(length($lane)*6)+3,$lane,$black);
	    $posX += $lanewidth;
	}
    }



	
}

sub InsertString {

    my ($self, $x, $y, $string) = @_;
    my $black = $self->{'image'}->colorAllocate(0,0,0);

    $self->{'image'} -> string(gdSmallFont,$x,$y,$string,$black) 
    
}


sub CreateImage {

    my ($self) = @_;
   
	return $self->{'image'}->png;

}

sub CreateGifImage {

    my ($self) = @_;
    
    return $self->{'image'}->gif;
}


sub CreatePngImage {

    my ($self) = @_;
    
    return $self->{'image'}->png;
}


1;


#-----------------------------------
# Set emacs perl mode for this file
#
# Local Variables:
# mode:perl
# End:
#
#-----------------------------------


# USAGE
# my $barcode = new BarcodeImage($bar_code,$quiet_zone,$polarity,$density,
#	$dpi,$image_type,$description);
#
# where:	$bar_code = string to be barcoded
#		$quiet_zone = number of clear x-dimensions each end
#		$polarity = bw (black on white) or wb (white on black)
#		$density = width of individual bars in .001 inch
#		$dpi = resolution of target printer
#		$image_type = 'transparent' or 'interlaced't
#		$description = optional description
# Returns the png file in $barcode->{'png_file'}.

#
# $Header$
#
