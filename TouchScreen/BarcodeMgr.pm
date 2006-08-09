# -*-Perl-*-

##############################################
# Copyright (C) 2000 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

##############################################
# TouchScreen Interface Barcode Data Manager #
##############################################

package TouchScreen::BarcodeMgr;
use strict;
use TouchScreen::Barcode;

#############################################################
# Methods to be exported
#############################################################

require Exporter;

our @ISA = qw (Exporter AutoLoader);
our @EXPORT = qw ( );


$::Pass = 'pass';
$::Fail = 'failed';


########################################
# Create new data management structure #
########################################
sub new {

    my ($class) = @_;

    my ($self) = {};
    bless $self, $class;

    $self -> {'InputPrefixes'} = undef;        
    $self -> {'OutputPrefixes'} = undef;    
    $self -> {'ActivePrefixes'} = [];
    $self -> {'DataStatus'} = 0;       
    $self -> {'IO_Mode'} = undef;     
    $self -> {'NumberOfScans'} = 0;
    $self -> {'ProcessId'} = undef;
    $self -> {'EmployeeId'} = undef;
    $self -> {'UsedInputBarcodes'} = [];
    $self -> {'UsedOutputBarcodes'} = [];
    $self -> {'Machine'} = undef;
    $self -> {'Reagents'} = [];
    $self -> {'Barcodes'} = [];

    return $self;
} #new


sub destroy {

    my ($self) = @_;
    undef %{$self}; 
    $self ->  DESTROY;

} #destroy



sub Set {
    
    my ($self, $info, $data) = @_;
    
    $self -> {$info} = $data;

    if(($info eq 'InputPrefixes')||($info eq 'OutputPrefixes')) { 
	$self -> AddActivePrefix($data);
    }
} #Set


sub Get {
    
    my ($self, $info) = @_;
    
    my $data = $self -> {$info};

    return ($data);
} #Get


sub ReInitInfo {

    my ($self) = @_;
    
    $self -> DestroyBarcodes;
    $self -> {'UsedInputBarcodes'} = [];
    $self -> {'UsedOutputBarcodes'} = [];
    $self -> {'Machine'} = undef;
    $self -> {'Reagents'} = [];
    $self->{'Active'} = undef;
 
} #ReInitInfo



sub GetBarcodes {

    my ($self) = @_;

    return $self->{'Barcodes'};
} # GetBarcodes


sub DestroyBarcodes {

    my ($self) = @_;

    for my $ref (@{$self->{'Barcodes'}}) {
	if(defined $ref) {
	    $ref -> destroy;
	}
    }

    $self -> {'Barcodes'} = [];
}

sub RemoveBarcode {
  my ($self, $barcode, $type) = @_;
  
  my $used = $type eq "in" ? $self -> {'UsedInputBarcodes'} : $self -> {'UsedOutputBarcodes'};

  for my $i (0 .. $#{$used}) {
    if(defined $used->[$i]) {
      if($used->[$i] eq $barcode) {
	$used->[$i] = undef;
	last;
      }
    }
  }
}

sub RemoveBarcodes {

    my ($self, $id) = @_;

    if(defined $id) {
	
	my (@inputs, @outputs);

	for my $i (0 .. $#{$self->{'Barcodes'}}) {
	    my $bar_ref = $self->{'Barcodes'}[$i];
	    if(defined $bar_ref) {
		if($id == $bar_ref -> Get('ScreenId')) {
		    push(@inputs, @{$bar_ref -> {'InputBarcodes'}});
		    push(@outputs, @{$bar_ref -> {'OutputBarcodes'}});
		    $bar_ref -> destroy;
		    $self->{'Barcodes'}[$i] = undef;
		}
	    }
	}

	# remove deleted barcodes from used lists
	my @used = @{$self -> {'UsedInputBarcodes'}};
	for my $i (0 .. $#used) {
	    if(defined $used[$i]) {
		foreach my $in (@inputs) {
		    if($used[$i] eq $in) {
			$self->{'UsedInputBarcodes'}[$i] = undef;
			last;
		    }
		}
	    }
	}

	@used = @{$self -> {'UsedOutputBarcodes'}};
	for my $i (0 .. $#used) {
	    if(defined $used[$i]) {
		foreach my $in (@outputs) {
		    if($used[$i] eq $in) {
			$self->{'UsedOutputBarcodes'}[$i] = undef;
			last;
		    }
		}
	    }
	}

    }
} #RemoveBarcodes



sub AddActivePrefix {
    
    my ($self, $data) = @_;
    push(@{$self -> {'ActivePrefixes'}}, $data);
}




sub AddUsedInputBarcode {

    my ($self, $input) = @_;

    push(@{$self -> {'UsedInputBarcodes'}}, $input);

}

sub CheckIfUsedInput {

    my ($self, $new) = @_;

    #allow primer prefix barcodes, which are more like reagents to be scanned multiple times
    return 1 if($new =~ /^21/);

    foreach my $in (@{$self -> {'UsedInputBarcodes'}}) {
	if(defined $in) {
	    if($in eq $new) {
		return 0;
	    }
	}
    }
    
    $self -> AddUsedInputBarcode($new) if($new ne 'empty');

    return 1;
}

sub AddUsedOutputBarcode {

    my ($self, $output) = @_;

    push(@{$self -> {'UsedOutputBarcodes'}}, $output);
    
}

sub CheckIfUsedOutput {

    my ($self, $new) = @_;
    
    foreach my $in (@{$self -> {'UsedOutputBarcodes'}}) {
	if(defined $in) {
	    if($in eq $new) {
		return 0;
	    }
	}
    }
    
    $self -> AddUsedOutputBarcode($new) if($new ne 'empty');

    return 1;
}

sub GetNumberOfScans {

    my ($self) = @_;
    
    my $bar_ref = $self->{'Active'};

    if(!(defined $bar_ref)) {
	return 0;
    }
    else {
	return  $bar_ref -> Get('NumberOfScans');
    }

}

sub AddBarcode {
    
    my ($self,$barcode,$desc,$position) = @_;

    my $barcode_ref = TouchScreen::Barcode->new($barcode,$desc, $position);

    my $barcode_data = push(@{$self -> {'Barcodes'}}, $barcode_ref); ;
    
    $self -> {'Active'} = $barcode_ref;
   
    return $barcode_ref;
}

1;

# $Header$
