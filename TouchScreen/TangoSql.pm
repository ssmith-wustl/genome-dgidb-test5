# -*-Perl-*-

##############################################
# Copyright (C) 2002 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

package TouchScreen::TangoSql;

use strict;
use DbAss;
use TouchScreen::CoreSql;
use TouchScreen::NewProdSql;

#############################################################
# Production sql code package
#############################################################

require Exporter;


our @ISA = qw (Exporter AutoLoader);
our @EXPORT = qw ( );

my $pkg = __PACKAGE__;

#########################################################
# Create a new instance of the Tango code so that you #
# can easily use more than one data base schema         #
#########################################################
sub new {

    # Input
    my ($class, $dbh, $schema) = @_;
    
    my $self;

    $self = {};
    bless $self, $class;

    $self->{'dbh'} = $dbh;
    $self->{'Schema'} = $schema;
    $self->{'Error'} = '';

    $self->{'CoreSql'} = TouchScreen::CoreSql->new($dbh, $schema);
    $self->{'ProdSql'} = TouchScreen::NewProdSql->new($dbh, $schema);
    
    $self->{'Tango Setup'} = [{'Name' => 'A1 Deck Position',
			       'Query'   => 'DeckPos',},
			      {'Name' => 'Sector A1',
			       'Query'   => 'GetAvailSeqDnaPf',}, 
			      {'Name' => 'A2 Deck Position',
			       'Query'   => 'DeckPos',},
			      {'Name' => 'Sector A2',
			       'Query'   => 'GetAvailSeqDnaPf',}, 
			      {'Name' => 'B1 Deck Position',
			       'Query'   => 'DeckPos',},
			      {'Name' => 'Sector B1',
			       'Query'   => 'GetAvailSeqDnaPf',}, 
			      {'Name' => 'B2 Deck Position',
			       'Query'   => 'DeckPos',},
			      {'Name' => 'Sector B2',
			       'Query'   => 'GetAvailSeqDnaPf',}, 
			      {'Name' => '384 Deck Position',
			       'Query'   => 'DeckPos',},
			      {'Name' => '384 well load plate',
			       'Query'   => 'CheckIfUsedAsOutput',}, 
			      {'Name' => 'A1 Deck Position',
			       'Query'   => 'DeckPos',},
			      {'Name' => 'Sector A1',
			       'Query'   => 'GetAvailSeqDnaPf',}, 
			      {'Name' => 'A2 Deck Position',
			       'Query'   => 'DeckPos',},
			      {'Name' => 'Sector A2',
			       'Query'   => 'GetAvailSeqDnaPf',}, 
			      {'Name' => 'B1 Deck Position',
			       'Query'   => 'DeckPos',},
			      {'Name' => 'Sector B1',
			       'Query'   => 'GetAvailSeqDnaPf',}, 
			      {'Name' => 'B2 Deck Position',
			       'Query'   => 'DeckPos',},
			      {'Name' => 'Sector B2',
			       'Query'   => 'GetAvailSeqDnaPf',}, 
			      {'Name' => '384 Deck Position',
			       'Query'   => 'DeckPos',},
			      {'Name' => '384 well load plate',
			       'Query'   => 'CheckIfUsedAsOutput',}, 
			      

			      ];
    

    $self->{'TangoRearrayMapping'} = {3 => {'Destination' =>  undef,
					    'Destination Quadrant' => undef,
					    'Next Postition' => 0,
					    'Barcode' => undef,
					    'Plate Barcode' => undef,
					},
				      4 => {'Destination' =>  undef,
					    'Destination Quadrant' => undef,
					    'Next Postition' => 0,
					    'Barcode' => undef,,
					    'Plate Barcode' => undef,
					},
				      5 => {'Destination' =>  3,
					    'Destination Quadrant' => 'a1',
					    'Next Postition' => 6,
					    'Barcode' => undef,,
					    'Plate Barcode' => undef,
					},
				      6 => {'Destination' =>  3,
					    'Destination Quadrant' => 'a2',
					    'Next Postition' => 7,
					    'Barcode' => undef,,
					    'Plate Barcode' => undef,
					},
				      7 => {'Destination' =>  3,
					    'Destination Quadrant' => 'b1',
					    'Next Postition' => 8,
					    'Barcode' => undef,,
					    'Plate Barcode' => undef,
					},
				      8 => {'Destination' =>  3,
					    'Destination Quadrant' => 'b2',
					    'Next Postition' => 3,
					    'Barcode' => undef,,
					    'Plate Barcode' => undef,
					},
				      
				      9 => {'Destination' =>  4,
					    'Destination Quadrant' => 'a1',
					    'Next Postition' => 10,
					    'Barcode' => undef,,
					    'Plate Barcode' => undef,
					},
				      10 => {'Destination' =>  4,
					     'Destination Quadrant' => 'a2',
					     'Next Postition' => 11,
					     'Barcode' => undef,,
					    'Plate Barcode' => undef,
					 },
				      11 => {'Destination' =>  4,
					     'Destination Quadrant' => 'b1',
					     'Next Postition' => 12,
					     'Barcode' => undef,,
					     'Plate Barcode' => undef,
					 },
				      12 => {'Destination' =>  4,
					     'Destination Quadrant' => 'b2',
					     'Next Postition' => 4,
					     'Barcode' => undef,,
					     'Plate Barcode' => undef,
					 },
				      

				   };
    $self->{'GetAvailSeqDnaPf'} = LoadSql($dbh, "select distinct pse.pse_id from 
               $schema.pse_barcodes barx, $schema.seq_dna_pses sdx,
               $schema.process_step_executions pse
               where 
                  barx.pse_pse_id = sdx.pse_pse_id and
                  barx.pse_pse_id = pse.pse_id and
                  pse.psesta_pse_status = ? and 
                  barx.bs_barcode = ? and 
                  barx.direction = ? and 
                  pse.ps_ps_id in 
                      (select ps_id from $schema.process_steps where  pro_process_to in
                      (select pro_process from $schema.process_steps where ps_id = ?) and      
                      purpose = ?)", 'List');
    
    
    $self->{'EquipmentEvent'} = LoadSql($dbh,"insert into $schema.pse_equipment_informations (equinf_bs_barcode, pse_pse_id)values (?, ?)", 'i');
    $self->{'GetBarcodeDesc'} = LoadSql($dbh,"select barcode_description from $schema.barcode_sources where barcode = ?", 'Single');
    $self -> {'DeckPos'} = LoadSql($dbh, "select unit_name from equipment_informations where bs_barcode = ? and EQU_EQUIPMENT_DESCRIPTION = 'Tango deck position'", 'Single');
    $self->{'NextDeckPosition'} = 0;
    $self->{'ActiveDeckPosition'} = 0;
    $self->{'ActiveScanPosition'} = 0;

    return $self;
}


###########################
# Commit a DB transaction #
###########################
sub commit {
    my ($self) = @_;
    $self->{'dbh'}->commit;
} #commit

###########################
# Commit a DB transaction #
###########################
sub rollback {
    my ($self) = @_;
    $self->{'dbh'}->rollback;
} #commit

#############################
# Destroy a Tango session #
#############################
sub destroy {
    my ($self) = @_;
    undef %{$self}; 
    $self ->  DESTROY;
} #destroy
   
#########################
# Retrieve CoreSqlError #
#########################
sub GetCoreError {
    my ($self) = @_;
    $self->{'Error'} = $self->{'CoreSql'}->{'Error'};
    return 0;
}


################################################################################
#                                                                              #
#                               Input verification subroutines                 #
#                                                                              #
################################################################################

sub CheckTangoSetupInfo {

    my ($self, $barcode, $ps_id) = @_;

    my $pos = $self->{'ActiveScanPosition'};
    my $info = $self->{'Tango Setup'}->[$pos];
    my $name = $info->{'Name'};
    my $query = $info->{'Query'};
    my $desc;

    if($pos >=20) {
	$self->{'Error'} = "$pkg: CheckTangoSetupInfo() -> All setup information entered. Please confirm or restart.";
	return 0;
    }

    #even odd check
    if(($pos % 2) == 0) {
	my $deck_pos = $self -> {$query} -> xSql($barcode);
	if(($self->{'NextDeckPosition'} eq $deck_pos) || (($self->{'NextDeckPosition'} == 0) && ($self->{'TangoRearrayMapping'}->{$deck_pos}->{'Destination Quadrant'} eq 'a1'))) {
	    $self->{'ActiveDeckPosition'} = $deck_pos;
	    $self->{'NextDeckPosition'} = $self->{'TangoRearrayMapping'}->{$deck_pos}->{'Next Postition'};
	    $self->{'TangoRearrayMapping'}->{$deck_pos} -> {'Barcode'} = $barcode;
	    $self->{'ActiveScanPosition'}++;
	    return($name);
	}
	
    }
    else {
	
	if($barcode =~ /^empty/) {
	    $self->{'ActiveScanPosition'}++;
	    return $barcode;
	}

	my ($result, $pse) = $self -> $query($barcode, $ps_id);
	
	if($result) {
	    $self->{'TangoRearrayMapping'}->{$self->{'ActiveDeckPosition'}} -> {'Plate Barcode'} = $barcode;
	    $self->{'TangoRearrayMapping'}->{$self->{'ActiveDeckPosition'}} -> {'pse'} = $pse if(defined $pse);
	    $self->{'ActiveScanPosition'}++;
	    return ($self->{'GetBarcodeDesc'}->xSql($barcode), [$pse]);
	}
    }
    
    $self->{'Error'} = "$pkg: CheckTangoSetupInfo() -> Could not determine setup information.";
    return 0;

} #CheckTangoSetupInfo


sub GetAvailSeqDnaPf {

    my ($self, $barcode, $ps_id) = @_;

    my $pses = $self -> {'GetAvailSeqDnaPf'} -> xSql('inprogress', $barcode, 'in', $ps_id, 'Directed Sequencing');
    
    return (1, $pses->[0]) if(defined $pses->[0]);
    
    return 0;
			      
}


sub CheckIfUsedAsOutput {

    my ($self, $barcode) = @_;

    my $desc = $self->{'CoreSql'} -> CheckIfUsed($barcode, 'out');
    return ($self->GetCoreError) if(!$desc);

    return 1;
    
}
################################################################################
#                                                                              #
#                              Output verification subroutines                 #
#                                                                              #
################################################################################


sub SetupTango {
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $status = 'inprogress';
    my $pse_result = '';

    my $dbh = $self->{'dbh'};

    foreach my $deck_pos (sort keys %{$self->{'TangoRearrayMapping'}}) {

	if(defined $self->{'TangoRearrayMapping'}->{$deck_pos}->{'Destination'}) {

	    my $dest_pos = $self->{'TangoRearrayMapping'}->{$deck_pos}->{'Destination'};
	    my $dest_quad = $self->{'TangoRearrayMapping'}->{$deck_pos}->{'Destination Quadrant'};
	    if((defined $self->{'TangoRearrayMapping'}->{$deck_pos}->{'Plate Barcode'}) && (defined $self->{'TangoRearrayMapping'}->{$dest_pos}->{'Plate Barcode'})) {
		
		my $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $self->{'TangoRearrayMapping'}->{$deck_pos}->{'pse'});
		
		my $new_pse_id =  $self->{'CoreSql'}->Process('GetNextPse');
		return (0) if(!$new_pse_id);
		
		$result = $self->{'CoreSql'}->Process('InsertPseEvent', '0', $status, $pse_result, $ps_id, $emp_id, $new_pse_id, $emp_id, 0, $pre_pse_ids->[0]);
		return (0) if(! $result);
		
		$result = $self->{'EquipmentEvent'} -> xSql($self->{'TangoRearrayMapping'}->{$deck_pos}->{'Barcode'}, $new_pse_id);
		if(!$result) {
		    $self->{'Error'} = "$pkg: SetupTango() -> Could not insert deck source/pse.";
		    return 0;
		}

		$result = $self->{'EquipmentEvent'} -> xSql($self->{'TangoRearrayMapping'}->{$dest_pos}->{'Barcode'}, $new_pse_id);
		if(!$result) {
		    $self->{'Error'} = "$pkg: SetupTango() -> Could not insert deck destination/pse.";
		    return 0;
		}

		$result = $self-> {'CoreSql'} -> Process('InsertBarcodeEvent', $self->{'TangoRearrayMapping'}->{$deck_pos}->{'Plate Barcode'}, $new_pse_id, 'in');
		return ($self->GetCoreError) if(!$result);
		$result = $self-> {'CoreSql'} -> Process('InsertBarcodeEvent', $self->{'TangoRearrayMapping'}->{$dest_pos}->{'Plate Barcode'}, $new_pse_id, 'out');
		return ($self->GetCoreError) if(!$result);
		
		
		my $sec_id =  $self -> {'CoreSql'} -> Process('GetSectorId', $dest_quad);
		return ($self->GetCoreError) if(!$sec_id);
		
		$result = $self -> {'ProdSql'} -> Trans96To384($self->{'TangoRearrayMapping'}->{$deck_pos}->{'Plate Barcode'}, $self->{'TangoRearrayMapping'}->{$deck_pos}->{'pse'}, $new_pse_id, $sec_id, 'sequenced_dna');
		return 0 if($result == 0);

		push(@{$pse_ids}, $new_pse_id);
	    }
	}
    }
	
    return $pse_ids;
} #SetupTango




#-----------------------------------
# Set emacs perl mode for this file
#
# Local Variables:
# mode:perl
# End:
#
#-----------------------------------

#
# $Header$
#
