# -*-Perl-*-

##############################################
# Copyright (C) 2001 Craig S. Pohl
#modmox Washington University, St. Louis
# All Rights Reserved.
##############################################
package TouchScreen::Barcode;
use strict;

#############################################################
# Methods to be exported
#############################################################

require Exporter;


our @ISA = qw(Exporter AutoLoader);
our @EXPORT = qw ( );

# create new barcode object
sub new {

    my ($class,$position) = @_;

    my $self = {};
    bless $self, $class;
    $self -> {'InputBarcodes'} = [];
    $self -> {'OutputBarcodes'} = [];
    $self -> {'Amount'} = 1;
    $self -> {'ScreenId'} = undef;
    $self -> {'NumberOfScans'} = 0;
    
    return $self;
} #new


# destroys barcode object
sub destroy {
    my ($self) = @_;
    undef %{$self}; 
    $self ->  DESTROY;

}

# set a barcode attribute
sub Set {
    
    my ($self, $info, $data) = @_;
    
    $self -> {$info} = $data;

    if(($info eq 'InputPrefixes')||($info eq 'OutputPrefixes')) { 
	$self -> AddActivePrefix($data);
    }
} #Set


# Gets a barcode attribute
sub Get {
    
    my ($self, $info) = @_;
    
    my $data = $self -> {$info};

    return ($data);
} #Get


sub SetDefinedOutput {

    my ($self, $row, $desc) = @_;

    $self -> {'DefinedOutput'} -> {$desc} = $row;
}

sub GetDefinedOutputRow {

    my ($self, $desc) = @_;

    my $row;

    $row = $self -> {'DefinedOutput'} -> {$desc};

    return $row;
}

sub NumDefinedOutputs {

    my ($self) = @_;

    my $num = keys %{$self -> {'DefinedOutput'}};

    return $num;
}


sub SetData {

    my ($self, $pso, $data) = @_;

    $self -> {'Data'} -> {$pso} = $data;
}


sub AddInputBarcode {

    my ($self, $input) = @_;

    push(@{$self -> {'InputBarcodes'}}, $input);

    $self->{'NumberOfScans'}++;
    
}
sub AddOutputBarcode {

    my ($self, $output) = @_;

    push(@{$self -> {'OutputBarcodes'}}, $output);
    
    $self->{'NumberOfScans'}++;
}

1;

# $Header$
