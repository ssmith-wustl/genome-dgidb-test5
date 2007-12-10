# -*-Perl-*-

##############################################
# Copyright (C) 2000 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

######################################
# TouchScreen Interface Data Manager #
######################################

package TouchScreen::FreezeSql;

use strict;
use ConvertWell;
use DBI;
use DbAss;
use TouchScreen::CoreSql;
use Mail::Send;
use App::Mail;

#############################################################
# Production sql code package
#############################################################

require Exporter;

our @ISA = qw(TouchScreen::CoreSql);
our @EXPORT = qw( );

my $pkg = __PACKAGE__;

#########################################################
# Create a new instance of the Freezer code so that you #
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

    #$self->{'CoreSql'} = new CoreSql($dbh, $schema);
    $self = $class->SUPER::new( $dbh, $schema);
    $self->{'GetBarcodeDesc'} = LoadSql($dbh,"select decode(barcode_description, 'none', content_description, barcode_description) from $schema.barcode_sources where barcode = ?", 'Single');
    $self->{'GetEquipmentBarcodeDesc'} = LoadSql($dbh,"select ei.equ_equipment_description || ' ' || bs.barcode_description from $schema.barcode_sources bs join $schema.equipment_informations ei on bs.barcode = ei.bs_barcode  where barcode = ?", 'Single');

    $self->{'GetEquipmentStatus'} = LoadSql($dbh, "select EIS_EQUIPMENT_STATUS from  $schema.equipment_informations
	                               where BS_BARCODE = ?", 'Single');

    $self->{'GetAvailabePosistions'} = LoadSql($dbh, "select unit_name, bs_barcode from equipment_informations where EQUINF_BS_BARCODE = ? 
                                       and EIS_EQUIPMENT_STATUS = 'vacant' order by lpad(unit_name,3)", 'ListOfList');
    $self -> {'GetMaxPseForCheckIn'} = LoadSql($dbh, "select max(pse_id) from $schema.pse_barcodes,$schema.process_step_executions 
               where pse_id = pse_pse_id and
               direction = 'in' and BS_BARCODE = ? and
               ps_ps_id in (select ps_id from $schema.process_steps where pro_process_to in 
               ('assign archive plate to storage location', 'assign freezer box to storage location', 'assign tube to freezer box location', 'check in' ))", 'Single');
    $self -> {'GetMaxPseForCheckOut'} = LoadSql($dbh, "select max(pse_id) from $schema.pse_barcodes,$schema.process_step_executions 
                where pse_id = pse_pse_id and
                direction = 'in' and BS_BARCODE = ? and
                ps_ps_id in (select ps_id from $schema.process_steps
                where pro_process_to in 
                ('retire all archives in a storage location','retire all contents in a storage location','retire archive plate from storage location', 
                'retire freezer box from storage location', 'retire tube from freezer box location', 'check out'))", 'Single');
    $self -> {'GetSlotDescFromPse'} =  LoadSql($dbh, "select barcode_description from $schema.barcode_sources where barcode = 
                (select equinf_bs_barcode from $schema.pse_equipment_informations where pse_pse_id = ?)", 'Single');
    $self -> {'GetSlotBarcodeFromPse'} =  LoadSql($dbh, "select equinf_bs_barcode from $schema.pse_equipment_informations where pse_pse_id = ?", 'Single');
    $self -> {'GetArchiveBarcodeFromPse'} =  LoadSql($dbh, "select distinct pb.bs_barcode from $schema.pse_equipment_informations pei, $schema.pse_barcodes pb where pb.pse_pse_id = pei.pse_pse_id and pei.pse_pse_id = ? and direction = 'in'", 'Single');
	
    $self->{'GetArchiveInfo'} = LoadSql($dbh, "select distinct archive_number
                 from $schema.archives an,
                      $schema.process_step_executions pse,
                      $schema.pse_barcodes psebc,
                      $schema.subclones_pses scp,
                      $schema.subclones sc
                 where
                 	an.arc_id = sc.arc_arc_id and
                    	psebc.bs_barcode = ? and
                  	scp.sub_sub_id = sc.sub_id and
                       	psebc.direction = 'out' and
                     	scp.pse_pse_id = pse.pse_id and
                      	pse.pse_id = psebc.pse_pse_id and
                     	pse.pse_id = scp.pse_pse_id and
                      	pse.ps_ps_id IN (select ps_id
                                       from process_steps
                                       where
                                       pro_process_to in ('pick', 'archive growth','generate archive plate barcode'))", 'List');
    $self->{'EquipmentEvent'} = LoadSql($dbh,"insert into $schema.pse_equipment_informations 
	    (equinf_bs_barcode, pse_pse_id) 
	    values (?, ?)");  
    $self->{'MaxEquipmentPse'} = LoadSql($dbh,"select max(pse_pse_id) from  $schema.pse_equipment_informations where equinf_bs_barcode = ?", 'Single');
    
    $self -> {'UpdateFreezerLocation'} = LoadSql($dbh,"update $schema.equipment_informations
             SET eis_equipment_status = ? 
	     WHERE bs_barcode = ?");
    $self -> {'GetEquipChildren'} = LoadSql($dbh,"select distinct bs_barcode from $schema.equipment_informations where equinf_bs_barcode = ?", 'List');
    $self -> {'GetEquipParent'} = LoadSql($dbh,"select distinct equinf_bs_barcode from $schema.equipment_informations where bs_barcode = ?", 'Single');
    $self -> {'CountChildrenStatus'} = LoadSql($dbh,  "select count(*) from $schema.equipment_informations where eis_equipment_status = ? 
                                       and equinf_bs_barcode = ?", 'Single');

     $self -> {'GetArchivesForBarcode'} = LoadSql($dbh, "select distinct archive_number from $schema.archives where arc_id in (select distinct arc_arc_id 
            from $schema.subclones where sub_id in (select sub_sub_id from $schema.subclones_pses where pse_pse_id in
            (select distinct pse_pse_id from $schema.pse_barcodes where bs_barcode = ? and direction = 'out')))", 'List');

    $self -> {'GetArcFromBar'} = LoadSql($dbh, qq/select distinct bs_barcode, pse_pse_id from gsc.pse_barcodes where
                                         direction = 'in' and pse_pse_id = (
                                                                            select max(pse.pse_id) from
                                                                            process_steps ps 
                                                                            join  process_step_executions pse on ps.ps_id = pse.ps_ps_id 
                                                                            join pse_equipment_informations pei on pse.pse_id = pei.pse_pse_id and equinf_bs_barcode = ?
                                                                            join equipment_informations ei on ei.bs_barcode = pei.equinf_bs_barcode
                                                                            where
                                                                            pro_process in
                                                                            ('assign archive plate to storage location',
                                                                             'assign freezer box to storage location',
                                                                             'assign tube to freezer box location') )/, 'ListOfList');

     $self->{'HasItBeExpunged'} = LoadSql($dbh, qq/select * from pse_barcodes pb, process_step_executions pse, process_steps ps
where 
  pb.pse_pse_id = pse.pse_id and ps.ps_id = pse.ps_ps_id 
  and pb.bs_barcode = ? and ps.pro_process_to = 'expunge from storage'/, "Single");

    $self -> {'UpdateBoxParentToNull'} = LoadSql($dbh,"update $schema.equipment_informations
             SET equinf_bs_barcode = null 
	     WHERE bs_barcode = ?");
    $self -> {'UpdateBoxParentToNewParent'} = LoadSql($dbh,"update $schema.equipment_informations
             SET equinf_bs_barcode = ? 
	     WHERE bs_barcode = ?");
     return $self;
} #new

###########################
# Commit a DB transaction #
###########################
sub commit {
    my ($self) = @_;
    $self->{'dbh'}->commit;
} #commit

#############################
# Destroy a FreezerSql session #
#############################
sub destroy {
    my ($self) = @_;
    undef %{$self}; 
    $self ->  DESTROY;
} #destroy

    

################################################################################
#                                                                              #
#                               Input verification subroutines                 #
#                                                                              #
################################################################################

###################################################
# return the freezer column for a barcode scanned #
###################################################
sub GetFreezerColumnDesc {
    my ($self, $barcode, $ps_id, $ei_id) = @_;
    
    my $column = $self->{'GetEquipmentBarcodeDesc'} -> xSql($barcode);
    unless (defined $column) {   
        $self->{'Error'} = "$pkg: GetFreezerColumnDesc() -> Could not find freezer description for barcode = $barcode.";
        return 0;
    }
    unless ($column =~ /column/i) {
        $self->{'Error'} = "$pkg: GetFreezerColumnDesc() -> $barcode is not a freezer column = $column";
        return 0;
    }

    my $status = $self->{'GetEquipmentStatus'} -> xSql($barcode);
    unless ($status eq 'vacant') {
	$self->{'Error'} = "$pkg: GetFreezerColumnDesc() -> Freezer column is occupied for barcode = $barcode.";
        return 0;
    }

    return $column;
} #GetFreezerColumnDesc


sub GetFreezerBoxWellDescWithCheck {
    my ($self, $barcode, $ps_id, $ei_id) = @_;

    my $checkin_pse_id = $self -> {'GetMaxPseForCheckIn'} -> xSql($barcode);
    #LSF: If the $barcode is a tube, check to see the box is still checkin.
    my $bar = GSC::Barcode->get(barcode => $barcode);
    unless($bar) {
      $self->{'Error'} = "Cannot find the barcode [$barcode] in the database!";
      return 0;
    }
    if($bar->container_type =~ /^freezer box/) {
      if($checkin_pse_id) {
	my $cpse = GSC::PSEEquipmentInformation->get(pse_id => $checkin_pse_id);
	if($cpse) {
	  my $ei = GSC::EquipmentInformation->get(barcode => $cpse->bs_barcode);
	  if($ei && $ei->equipment_description =~ /freezer rack slot/i) { 
	    if($self->GetFreezerBarcodeDescToCheckout($barcode, $ps_id)) {
              $self->{'Error'} = "Cannot assign to the box [" . $barcode . '] because it has NOT been checked out yet.';
	      return 0;
	    }
	    $self->{'Error'} = '';
	  }
	}
      }
    }
    
    return $self->GetFreezerBoxDesc($barcode, $ps_id, $ei_id);
}

sub GetFreezerBoxDesc {
    my ($self, $barcode, $ps_id, $ei_id) = @_;
    
    my $desc = $self->{'GetEquipmentBarcodeDesc'} -> xSql($barcode);
    unless (defined $desc) {   
        $self->{'Error'} = "$pkg: GetFreezerBoxDesc() -> Could not find freezer description for barcode = $barcode.";
        return 0;
    }
    unless ($desc =~ /freezer box/i) {
        $self->{'Error'} = "$pkg: GetFreezerBoxDesc() -> $barcode is not a freezer box = $desc";
        return 0;
    }

    my $status = $self->{'GetEquipmentStatus'} -> xSql($barcode);
    unless ($status eq 'vacant') {
	$self->{'Error'} = "$pkg: GetFreezerBoxDesc() -> Freezer box is occupied for barcode = $barcode.";
        return 0;
    }

    return $desc;
} #GetFreezerBoxDesc


sub GetFreezerBoxColumnDesc {
  my $self = shift;
  my $barcode = shift;
  my ($prefix) = ($barcode =~ /^(.{2,2})/);
  my %prefixes = map { $_->barcode_prefix => $_ } GSC::BarcodePrefix->get(container_type => { operator => 'LIKE', value => 'freezer box%' });
  if(defined $prefixes{$prefix}) {
    return $self->GetFreezerColumnDesc($barcode);
  }
  $self->{'Error'} = "Barcode $prefix [$barcode] prefix is invalid!.  Please scan in the prefix listed [" . (join ",", keys %prefixes) . "]";
  return;
}

###########################################
# Get a Freezer description for a barcode #
###########################################
sub GetFreezerDesc {
    my ($self, $barcode, $ps_id) = @_;
    
    my $desc = $self->{'GetEquipmentBarcodeDesc'} -> xSql($barcode);
    
    if(defined $desc) {
	return $desc;
    }
    
    $self->{'Error'} = "$pkg: GetFreezerDesc() -> Could not find freezer desc for barcode = $barcode.";

    return 0;
} #GetFreezerDesc


##############################################
# Get description of a 96 well archive plate #
##############################################
sub GetFreezerBarcodeDesc96 {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pre_pses)=$self -> GetFreezerBarcodeDesc($barcode, $ps_id, '96 archive plate');

    return ($result, $pre_pses);
} #GetFreezerBarcodeDesc96

###############################################
# Get description of a 384 well archive plate #
###############################################
sub GetFreezerBarcodeDesc384 {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pre_pses)=$self -> GetFreezerBarcodeDesc($barcode, $ps_id, '384 archive plate');

    return ($result, $pre_pses);
} #GetFreezerBarcodeDesc384

#######################################
# Get description of an archive plate #
#######################################
sub GetFreezerBarcodeDesc {

    my ($self, $barcode, $ps_id, $type) = @_;
    
#    my $checkin_pse_id = $self -> {'GetMaxPseForCheckIn'} -> xSql($barcode, $type);
#    my $slot_desc = $self -> {'GetSlotDescFromPse'} -> xSql($checkin_pse_id);
#    
#    my $lov = $self -> {'GetArchivesForBarcode'} -> xSql($barcode);
#    
#    if(defined $lov->[0]) {
#	return ("@{$lov}".' in '.$slot_desc, [$checkin_pse_id]);
#    }
#    $self->{'Error'} = "$pkg: GetFreezerBarcodeDesc() -> Could not find archive numbers for barcode = $barcode, ps_id = $ps_id.";
    

    my $retire_pse_id = $self -> {'GetMaxPseForCheckOut'} -> xSql($barcode);
    if (defined $retire_pse_id ) {
	
	# determine if the archive has been checked out
	my $assign_pse_id = $self -> {'GetMaxPseForCheckIn'} -> xSql($barcode);
	
	if(defined $assign_pse_id) {
	    if($retire_pse_id > $assign_pse_id) {
		$self->{'Error'} = "Archive Plate barcode = $barcode already retired.";
		return 0;
	    }
	}
	else {
	    $self->{'Error'} = "Archive Plate barcode = $barcode already retired.";
	    return 0;
	}
    }

    my $checkin_pse_id = $self -> {'GetMaxPseForCheckIn'} -> xSql($barcode);
    my $slot_desc = $self -> {'GetSlotDescFromPse'} -> xSql($checkin_pse_id);
    
    my $lov = $self -> {'GetArchivesForBarcode'} -> xSql($barcode);
    
    if(defined $lov->[0]) {
	return ("@{$lov}".' in '.$slot_desc, [$checkin_pse_id]);
    }
    
    $self->{'Error'} = "$pkg: GetFreezerBarcodeDesc() -> Could not find archive numbers for barcode = $barcode.";
    
    return 0;
} #GetFreezerBarcodeDesc


#######################################
# Get description of an archive plate #
#######################################
sub GetFreezerBarcodeDescToCheckout {

    my ($self, $barcode, $ps_id) = @_;

    my $type = 'none';
    
    
    my $retire_pse_id = $self -> {'GetMaxPseForCheckOut'} -> xSql($barcode);
    if (defined $retire_pse_id ) {
	
	# determine if the archive has been checked out
	my $assign_pse_id = $self -> {'GetMaxPseForCheckIn'} -> xSql($barcode);
	
	if(defined $assign_pse_id) {
	    if($retire_pse_id > $assign_pse_id) {
		$self->{'Error'} = "Archive Plate barcode = $barcode already retired.";
		return 0;
	    }
	}
	else {
	    $self->{'Error'} = "Archive Plate barcode = $barcode already retired.";
	    return 0;
	}
    }

    my $checkin_pse_id = $self -> {'GetMaxPseForCheckIn'} -> xSql($barcode);
    #LSF: If the $barcode is a tube, check to see the box is still checkin.
    my $bar = GSC::Barcode->get(barcode => $barcode);
    unless($bar) {
      $self->{'Error'} = "Cannot find the barcode [$barcode] in the database!";
      return 0;
    }
    if($checkin_pse_id && $bar->container_type eq "tube") {
      my $cpse = GSC::PSEEquipmentInformation->get(pse_id => $checkin_pse_id);
      my $ei = GSC::EquipmentInformation->get(barcode => $cpse->bs_barcode);
      if($ei && $ei->equipment_description =~ /freezer box|well box/i) { 
	if($self->GetFreezerBarcodeDescToCheckout($ei->equinf_bs_barcode, $ps_id)) {
          $self->{'Error'} = "Cannot check out tube [$barcode] because the box [" . $ei->equinf_bs_barcode . '] has NOT been checked out yet.';
	  return;
	}
	$self->{'Error'} = '';
      }
    }

    if(defined $checkin_pse_id) {
	my $slot_desc = $self -> {'GetSlotDescFromPse'} -> xSql($checkin_pse_id);
	
	my $desc = $self -> {'GetBarcodeDesc'} -> xSql($barcode);
	
	if(defined $desc) {
	    return ($desc.' in '.$slot_desc, [$checkin_pse_id]);
	}
	$self->{'Error'} = "$pkg: GetFreezerBarcodeDescToCheckout() -> Could not find barcode desc for barcode = $barcode, ps_id = $ps_id.";
    }
    else {
	$self->{'Error'} = "$pkg: GetFreezerBarcodeDescToCheckout() -> Could not find barcode in a freezer position barcode = $barcode, ps_id = $ps_id.";
    }
    
   return 0;
} #GetFreezerBarcodeDescToCheckout



################################################################################
#                                                                              #
#                              Output verification subroutines                 #
#                                                                              #
################################################################################

#########################################################
# determine the slots available for a freezer postition #
#########################################################
sub GetAvailableFreezerPositions {

    my ($self, $barcode) = @_;
    

    my $slots = $self->{'GetAvailabePosistions'} -> xSql($barcode);
    if(defined $slots->[0][0]) {
	my $list = [];
	foreach my $slot (@{$slots}) {
	    push (@{$list}, $slot->[0]);
	}
	return $list;
    }
    
    $self->{'Error'} = "$pkg: GetAvailableFreezerPositions() -> Could not find vacant freezer slots for barcode = $barcode.";
    
    return 0;
} #GetAvailableFreezerPositions


##############################################
# Check if a 96 well plate in freezer a slot #
##############################################
sub CheckIfArchiveInFreezer96 {

   my ($self, $barcode) = @_;
   my $result = $self -> CheckIfArchiveInFreezer($barcode, '96 archive plate');
   
   return $result;

} #CheckIfArchiveInFreezer96

###############################################
# Check if a 384 well plate in freezer a slot #
###############################################
sub CheckIfArchiveInFreezer384 {

   my ($self, $barcode) = @_;

   my $result = $self -> CheckIfArchiveInFreezer($barcode, '384 archive plate');
  
   return $result;

} #CheckIfArchiveInFreezer384
   

#############################################
# Get list of Archive Numbers for a barcode #
#############################################
sub CheckIfArchiveInFreezer {

   my ($self, $barcode, $type) = @_;

   # determine if the archive has been checked in a freezer before
   my $assign_pse_id = $self -> {'GetMaxPseForCheckIn'} -> xSql($barcode);
   if (defined $assign_pse_id ) {
       
       # determine if the archive has been checked out
       my $retire_pse_id = $self -> {'GetMaxPseForCheckOut'} -> xSql($barcode);

       if(defined $retire_pse_id) {
	   if($retire_pse_id < $assign_pse_id) {
	       my $desc = $self -> {'GetSlotDescFromPse'} -> xSql($assign_pse_id);
	       $self->{'Error'} = "Archive Plate barcode = $barcode assigned to slot $desc.";
	       return 0;
	   }
       }
       else {
	   my $desc = $self -> {'GetSlotDescFromPse'} -> xSql($assign_pse_id);
	   $self->{'Error'} = "Archive Plate barcode = $barcode assigned to slot $desc.";
	   return 0;
       }
   }
   my $lov =  $self->{'GetArchiveInfo'}->xSql($barcode);
       
   if(defined $lov->[0]) {
       return "@{$lov}";
   }

   $self->{'Error'} = "$pkg: CheckIfArchiveInFreezer() -> Could not find archive numbers for barcode = $barcode.";
   


   return 0;
} #GetArchiveNumFromBarcode


############################################################## 
# check if barcode available for checkin to freezer position #
##############################################################

sub CheckIfBarcodeInFreezer {

   my ($self, $barcode) = @_;

   # determine if the archive has been checked in a freezer before
   my $assign_pse_id = $self -> {'GetMaxPseForCheckIn'} -> xSql($barcode);
   if (defined $assign_pse_id ) {
       
       # determine if the archive has been checked out
       my $retire_pse_id = $self -> {'GetMaxPseForCheckOut'} -> xSql($barcode);

       if(defined $retire_pse_id) {
	   if($retire_pse_id < $assign_pse_id) {
	       my $desc = $self -> {'GetSlotDescFromPse'} -> xSql($assign_pse_id);
	       $self->{'Error'} = "Archive Plate barcode = $barcode assigned to slot $desc.";
	       return 0;
	   }
       }
       else {
	   my $desc = $self -> {'GetSlotDescFromPse'} -> xSql($assign_pse_id);
	   $self->{'Error'} = "Archive Plate barcode = $barcode assigned to slot $desc.";
	   return 0;
       }
   }
   #LSF: Put a check to make sure there is dna in the barcode; otherwise, don't allow it to put there.
   #LSF: If the barcode is a barcode don't check for dna.
   my @eis = grep { $_->equipment_description =~ /freezer box|well box/i } GSC::EquipmentInformation->get(barcode => $barcode);
   if(! @eis) {
     my @pbs = GSC::PSEBarcode->get(sql => [qq/select pb.* from pse_barcodes pb, dna_pse dp where pb.pse_pse_id = dp.pse_id and rownum < 2 and pb.bs_barcode = ?/, $barcode]);
     @pbs = GSC::PSEBarcode->get(sql => [qq/select pb.* from pse_barcodes pb, custom_primer_pse dp where pb.pse_pse_id = dp.pse_pse_id and rownum < 2 and pb.bs_barcode = ?/, $barcode]) unless(@pbs);
     unless(@pbs) {
       $self->{'Error'} = "Archive Plate barcode = $barcode do NOT have DNA.";
       return 0;
     }
   }
   my $desc =  $self->{'GetBarcodeDesc'}->xSql($barcode);
       
   if(defined $desc) {
       return $desc;
   }

   $self->{'Error'} = "$pkg: CheckIfBarcodeInFreezer() -> Could not find barcode description for barcode = $barcode.";
   


   return 0;
} #CheckIfBarcodeInFreezer


############################################################################################
#                                                                                          #
#                         Confirm Subrotine Processes                                      #
#                                                                                          #
############################################################################################


##############################################
# Link a archive barcode with a freezer slot #
##############################################
sub PutArchivePlateInFreezerSlot  {

    my ($self, $ps_id, $bars_in, $bars_out, $ei_id, $options, $pre_pse_ids) = @_;
    
    my $col_bar = $bars_in->[0];
    my $bar_out = $bars_out->[0];
    my $pses = [];
    my $slots = $self->{'GetAvailabePosistions'} -> xSql($bars_in->[0]);
    my $slot_bar;
    
    foreach my $i (0 .. $#{$bars_out}) {
	
	my $arch_bar = $bars_out->[$i];
	$slot_bar = $slots->[$i][1];

	my $pse_id =  $self->Process('GetNextPse');
	if(!$pse_id) {
	    $self->{'Error'} = $self->{'Error'};
	    return 0;
	}
	#LSF: Since it is just to fill an unknown history.
	#     We are going to make it 0 as the prior_pse_id if there isn't one.    
	unless($pre_pse_ids && @{$pre_pse_ids}) {
	  $pre_pse_ids = [0];
	}
	#PSE_SESSION,PSESTA_PSE_STATUS, PR_PSE_RESULT, PS_PS_ID, EI_EI_ID, PSE_ID, EI_EI_ID_CONFIRM, PIPE
	my $result = $self->Process('InsertPseEvent', '0','inprogress', '', $ps_id, $ei_id, $pse_id, $ei_id, 0, $pre_pse_ids->[0]);
	if(!$result) {
	    $self->{'Error'} = $self->{'Error'};
	    return 0;
	}
   
	#bs_barcode, pse_pse_id, direction
	$result = $self->Process('InsertBarcodeEvent', $arch_bar, $pse_id, 'in');
	if(!$result) {
	    $self->{'Error'} = $self->{'Error'};
	    return 0;
	}

	$result = $self->{'EquipmentEvent'} -> xSql($slot_bar, $pse_id);
	if(!$result) {
	    $self->{'Error'} = "Could not insert equipment event where pse_id = $pse_id, equinf_bs_barcode = $slot_bar.";
	    return 0;
	}
	
	$self -> {'UpdateFreezerLocation'} -> xSql('occupied', $slot_bar);
	
        $result =  $self->Process('UpdatePse', 'completed', 'successful', $pse_id);
	if(!$result) {
	    $self->{'Error'} = $self->{'Error'};
	    return 0;
	}


        # check to see if what is being stored in the position is a equipment barcode
        # so that we update the equipment table with its new parent
        my $abar = GSC::Barcode->get($arch_bar);
        if($abar->container_type_isa('freezer box') 
           || $abar->container_type_isa('96 well box') 
           || $abar->container_type_isa('freezer box 9x9')) {
            $self->{'UpdateBoxParentToNewParent'}->xSql($slot_bar, $arch_bar);
            #my $freezer_position = GSC::EquipmentInformation->get(barcode =>$arch_bar);
            #$freezer_position->equinf_bs_barcode($slot_bar);
        }
	
	my $freezer_group = Query($self->{'dbh'}, qq/select gro_group_name from equipment_informations where bs_barcode = '$slot_bar'/);
	
	if($freezer_group eq 'Prefinish/Finish') {
	    my $result = $self -> CompleteFinishingRequest($slot_bar, $arch_bar);
	    if(!$result) {
		$self->{'Error'}="$pkg: PutArchivePlateInFreezerSlot -> Failed completing finisher request.";
		return (0);
	    }
	}

	push(@{$pses}, $pse_id);
    }
    
    # use the last slot barcode to determine if parent is filled
    my $result = $self -> UpdateFreezerStatus($slot_bar,  0);
    return 0 if(!$result);
	
    return($pses) ;
} #PutArchivePlateInFreezerSlot



##########################
# retire plate from slot #
##########################
sub RetireArchivePlateFromFreezer {
    
    my ($self, $ps_id, $bars_in, $bar_out, $ei_id, $options, $pre_pse_ids) = @_;
     
    my $pses = [];
    my $bar_in = $bars_in->[0];

    my $pre_pse_id = $pre_pse_ids->[0];
    
    my $slot_bar = $self -> {'GetSlotBarcodeFromPse'} -> xSql($pre_pse_id);
    $self -> {'UpdateFreezerLocation'} -> xSql('vacant', $slot_bar);
  
    my $pse_id =  $self->Process('GetNextPse');
    if(!$pse_id) {
	$self->{'Error'} = $self->{'Error'};
	return 0;
    }
    
    #LSF: Since it is just to fill an unknown history.
    #     We are going to make it 0 as the prior_pse_id if there isn't one.    
    unless($pre_pse_ids && @{$pre_pse_ids}) {
      $pre_pse_ids = [0];
    }
    #PSE_SESSION,PSESTA_PSE_STATUS, PR_PSE_RESULT, PS_PS_ID, EI_EI_ID, PSE_ID, EI_EI_ID_CONFIRM, PIPE
    my $result = $self->Process('InsertPseEvent', '0','completed', 'successful', $ps_id, $ei_id, $pse_id, $ei_id, 0, $pre_pse_ids->[0]);
    if(!$result) {
	$self->{'Error'} = $self->{'Error'};
	return 0;
    }
    
    #bs_barcode, pse_pse_id, direction
    $result = $self->Process('InsertBarcodeEvent', $bar_in, $pse_id, 'in');
    if(!$result) {
	$self->{'Error'} = $self->{'Error'};
	return 0;
    }
    
    push(@{$pses}, $pse_id);

    # check to see if what is being stored in the position is a equipment barcode
    # so that we can null out the parent
    # LSF: If we do not null out the parent before the update freezer status and the "box" is full,
    # it will think the parent is occupied.  Therefore, we cannot use the app to update.
    my $abar = GSC::Barcode->get($bar_in);
    if($abar->container_type_isa('freezer box') 
       || $abar->container_type_isa('96 well box') 
       || $abar->container_type_isa('freezer box 9x9')) {
        
	$self -> {'UpdateBoxParentToNull'}->xSql($bar_in);
        #my $freezer_position = GSC::EquipmentInformation->get(barcode =>$bar_in);
        #$freezer_position->equinf_bs_barcode(undef);

    }
    $self -> UpdateFreezerStatus($slot_bar, 0);

    $result =  $self->Process('UpdatePse', 'completed', 'successful', $pse_id);
    if(!$result) {
	$self->{'Error'} = $self->{'Error'};
	return 0;
    }

	
    
    return($pses);
} #RetireArchivePlateFromFreezerSlot


#############################################
# Retire all children of the parent barcode #
#############################################
sub RetireAllArchivesFromStorageLoc {
    
    my ($self, $ps_id, $bars_in, $bar_out, $ei_id, $options) = @_;

    my $pses = [];

    my $parent_barcodes = [];
    $parent_barcodes->[0] = $bars_in->[0];
    my $found_children = 1;

    while($found_children) {
	my $temp_parent_barcodes = [];

	foreach my $parent_bar (@{$parent_barcodes}) {
	    my $children = $self -> {'GetEquipChildren'} -> xSql($parent_bar);
	    if(defined $children->[0]) {
		foreach my $child (@{$children}) {
		    my $status = $self->{'GetEquipmentStatus'} -> xSql($child);
		    if($status eq 'occupied') {
			my $lol = $self -> {'GetArcFromBar'} -> xSql($child);
			if(defined $lol->[0][0]) {
			    my $arc_bar = $lol->[0][0];
			    my $pre_pse = $lol->[0][1];
			    my $result;
			    if($arc_bar =~ /^12/) {
				$result =  $self -> RetireArchivePlateFromFreezer($ps_id, [$arc_bar], [$child], $ei_id, $options, [$pre_pse]);
				#push(@{$pses}, @{$result});
			    }
			    else {
				$result =  $self -> RetireArchivePlateFromFreezer($ps_id, [$arc_bar], [$child], $ei_id, $options, [$pre_pse]);
				#push(@{$pses}, @{$result});
			    }
			    if($result) {
			      push @{$pses}, @{$result}; 
			    } else {
			      return 0;
			    }
			}
		    }
		}
		push(@{$temp_parent_barcodes}, @{$children});
	    }
	    else {
		$found_children = 0;
	    }
	}
	if(($found_children) || (defined $temp_parent_barcodes->[0])) {
	    $parent_barcodes = [];
	    push(@{$parent_barcodes}, @{$temp_parent_barcodes});
	    $found_children = 1;
	}
    }

    $self -> UpdateFreezerStatus($bars_in->[0], 1);

    return $pses;
} #RetireAllArchivesFromStorageLoc




############################################################################################
#                                                                                          #
#                      Information Retrevial Subrotines                                    #
#                                                                                          #
############################################################################################


#########################
# Update Freezer Status #
#########################
sub UpdateFreezerStatus {

    my ($self, $barcode, $found_children) = @_;
    
    my $parent_barcodes = [];
    $parent_barcodes->[0] = $barcode;
    $found_children ||= 0;
    my $last_parents = [];

    while($found_children) {
	my $temp_parent_barcodes = [];
	foreach my $parent_bar (@{$parent_barcodes}) {
	    my $children = $self -> {'GetEquipChildren'} -> xSql($parent_bar);
	    if(!defined $children) {
		$found_children = 0;
		last;
	    }
	    else {
		push(@{$temp_parent_barcodes}, @{$children});
	    }
	}
	if(($found_children) || (defined $temp_parent_barcodes->[0])) {
	    $last_parents = $parent_barcodes;
	    $parent_barcodes = [];
	    push(@{$parent_barcodes}, @{$temp_parent_barcodes});
	    $found_children = 1;
	}
	
    }
    
    if(!defined $last_parents->[0]) {
	my $parent = $self->{'GetEquipParent'} -> xSql($barcode);
	push(@{$last_parents}, $parent);
    }

    my $found_vacant = 1;

    while($found_vacant) {
	my $temp_parents = [];
    
	foreach my $parent (@{$last_parents}) {
	    my $count = $self -> {'CountChildrenStatus'} -> xSql('vacant', $parent);
	    if($count == 0) {
		my $result = $self -> {'UpdateFreezerLocation'} -> xSql('occupied', $parent);
		push(@{$temp_parents}, $self->{'GetEquipParent'} -> xSql($parent));
	    } 
	    else {
		my $result = $self -> {'UpdateFreezerLocation'} -> xSql('vacant', $parent);
		push(@{$temp_parents}, $self->{'GetEquipParent'} -> xSql($parent));
	    }
	}
	if(!defined $temp_parents->[0]) {
	    $found_vacant = 0;
	}
	else {
	    $last_parents = [];
	    push(@{$last_parents}, @{$temp_parents});
	}
    }

    return 1;
} #UpdateFreezerStatus





sub CompleteFinishingRequest {
    
    my ($self, $slot_bar, $arch_bar) = @_;

    my $dbh = $self->{'dbh'};
    $self -> {'FinishRequestPse'} = LoadSql($dbh, qq/select distinct pse_id from pse_barcodes pb, process_steps, process_step_executions pse
					    where 
					    bs_barcode = ? and 
					    direction = 'in' and
					    psesta_pse_status = 'inprogress' and
					    purpose = 'Finisher Request' and
					    pro_process_to = 'freezer request' and
					    ps_ps_id = ps_id and 
					    pse_id = pse_pse_id/, 'Single');
    
    #$self -> {'FinishRequestSubclones'} = LoadSql($dbh, qq/select distinct subclone_name from subclones_pses, subclones
	#					  where
	#					  pse_pse_id = ? and
	#					  sub_sub_id = sub_id/, 'List');

    $self -> {'FinishRequestArchives'} = LoadSql($dbh, qq/select distinct archive_number from subclones_pses, subclones, archives
						 where
						 pse_pse_id = ? and
						 sub_sub_id = sub_id and
						 arc_arc_id = arc_id /, 'List');

    $self -> {'FinishRequestDNAs'} = LoadSql($dbh, qq/select distinct dna_name from dna d
					     join dna_pse dp on dp.dna_id = d.dna_id
					     where dp.pse_id = ?/, 'List');


    $self -> {'FinishRequestLogin'} = LoadSql($dbh, qq/select distinct unix_login 
					      from gsc_users gu, employee_infos ei, process_step_executions pse
					      where
					      pse_id = ? and
					      pse.ei_ei_id = ei.ei_id and 
					      ei.gu_gu_id = gu.gu_id/, 'Single');


    my $rq_pse = $self -> {'FinishRequestPse'} -> xSql($arch_bar);

    if(defined $rq_pse) {
	#my $subclones = $self -> {'FinishRequestSubclones'} -> xSql($rq_pse);
	my $dnas = $self -> {'FinishRequestDNAs'} -> xSql($rq_pse);
	my $archives  = $self -> {'FinishRequestArchives'} -> xSql($rq_pse);
	my $unix_login = $self -> {'FinishRequestLogin'} -> xSql($rq_pse);
	my $slot_desc = $self->{'GetEquipmentBarcodeDesc'} -> xSql($slot_bar);
	
	my $mail_msg;
	my $arc_bc = GSC::Barcode->get(barcode=>$arch_bar);
	my $fl = $arc_bc->freezer_location;
	
	$mail_msg .= "Hello $unix_login,\n\n";
	$mail_msg .= "Your request for plate $arch_bar has been filed in the finishing request freezer in\n";
	$mail_msg .= "\tSlot = $fl\n\n";

	if ($archives){
	    $mail_msg .= "The following archives have been requested on this plate:\n";
	    foreach my $archive (@{$archives}) {
		$mail_msg .= "\t$archive\n";
	    }
	}
	else {
	    $mail_msg .= "The following dnas were requested on this plate:\n"; 
	    my @ds = GSC::DNA->get(dna_name => $dnas);
	    my @dps = GSC::DNAPSE->get(dna_id => \@ds);
	    my %hdp;
	    foreach my $dp (@dps) {
	      push @{$hdp{$dp->dna_id}}, $dp;
	    }
	    my %dl = map { $_->dl_id => $_ } GSC::DNALocation->get(dl_id => \@dps);
	    my @pbs = GSC::PSEBarcode->get(pse_id => \@dps, barcode => $arch_bar, direction => 'out');
	    my %hpb;
	    foreach my $pb (@pbs) {
	      push @{$hpb{$pb->pse_id}}, $pb;
	    }
	    foreach my $dna (@ds) {
	      my $found = 0;
	      if($hdp{$dna->dna_id}) {
	        foreach my $dp (@{$hdp{$dna->dna_id}}) {
		  if($hpb{$dp->pse_id}) {
		    $mail_msg .= "\t", $dna->dna_name, " in well ", $dl{$dp->dl_id}->location_name, "\n";
		    $found = 1;
		    last;
		  }
		}
	      }
	      unless($found) {
	        $self->{'Error'} = "Cannot find the well location for dna " . $dna->dna_name . "[" . $dna->dna_id . "]";
	        return;
	      }
	    }
	    
=cut
	    foreach my $dna (@{$dnas}) {
		my $location = GSC::DNALocation->get(sql => [qq/select dl.* from dna d
						     join dna_pse dp on d.dna_id = dp.dna_id
						     join dna_location dl on dl.dl_id = dp.dl_id
						     join pse_barcodes pb on pb.pse_pse_id = dp.pse_id
						     join process_step_executions pse on pse.pse_id = dp.pse_id
						     join process_steps ps on ps.ps_id = pse.ps_ps_id
						     where dna_name = '$dna'
						     and pb.bs_barcode = '$arch_bar'
						     and pb.direction = 'out'/]);

		my $loc = $location->location_name;
		$mail_msg .= "\t$dna in well $loc\n";
	    }
=cut
	}
	$mail_msg .= "\nHappy Finishing,\nYour local Touch Screen application\n";
	App::Mail->mail(To=>"$unix_login\@watson.wustl.edu",
			From=>"Techs at the Touchscreen <autobulk\@watson.wustl.edu>",
			Subject=>"Finisher Request Filled",
			Message=>$mail_msg);

	my $result =  $self->Process('UpdatePse', 'completed', 'successful', $rq_pse);
	if(!$result) {
	    $self->{'Error'} = $self->{'Error'};
	    return 0;
	}

    }
    
    return 1;
}

=head2 hasItBeExpunged

Has this barcode has been expunged?

=cut

sub hasItBeExpunged {
  my $self = shift;
  my($barcode) = @_; 
  
  if($self->{'HasItBeExpunged'}-> xSql($barcode)) {
    $self->{'Error'} = "$pkg: HasItBeExpunged -> This $barcode was expunged before.";
    return 0;
  }
  my $bar = GSC::Barcode->get(barcode => $barcode);
  if($bar->container_type eq 'tube') {
    return $self->GetFreezerBarcodeDescToCheckout($barcode, 0);
  } else {
    return $self->getBarcodeDescription($barcode);
  }
}

=pod

=item is_box_still_checked_in

Check the tube barcode that in a box whether it is checked in in freezer.

PARAMS: $barcode - tube barcode to be checked
RETURN: boolean

=cut

sub is_box_still_checked_in {
  my $self = shift;
  my $barcode = shift;
  my $ps_id = shift;
  my $checkin_pse_id = $self -> {'GetMaxPseForCheckIn'} -> xSql($barcode);
  #LSF: If the $barcode is a tube, check to see the box is still checkin.
  my $bar = GSC::Barcode->get(barcode => $barcode);
  unless($bar) {
    $self->{'Error'} = "Cannot find the barcode [$barcode] in the database!";
    return 0;
  }
  if($checkin_pse_id && $bar->container_type eq "tube") {
    my $cpse = GSC::PSEEquipmentInformation->get(pse_id => $checkin_pse_id);
    my $ei = GSC::EquipmentInformation->get(barcode => $cpse->bs_barcode);
    if($ei && $ei->equipment_description =~ /freezer box/i) { 
      if($self->GetFreezerBarcodeDescToCheckout($ei->equinf_bs_barcode, $ps_id)) {
        $self->{'Error'} = "Cannot check out tube [$barcode] because the box [" . $ei->equinf_bs_barcode . '] has NOT been checked out yet.';
	return 0;
      }
      $self->{'Error'} = '';
    }
  }
  return 1;
}
=head2 expungeFromStorage

Expunge the plate from storage

=cut

sub expungeFromStorage {
  my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

  #If the barcode is in the freezer, retire it first and expunge it.
  my($fdesc, $fpse_ids) = $self->GetFreezerBarcodeDescToCheckout($bars_in->[0], $ps_id);
  if($fdesc) {
    my $ps = GSC::ProcessStep->get(ps_id => $ps_id);
    #Find the retire from freezer ps_id
    my @pss = GSC::ProcessStep->get(group_name => $ps->group_name, purpose => 'Storage Management', process_step_status => 'active', process => 'assign archive plate to storage location', process_to => 'retire archive plate from storage location');
    if(@pss) {
      #Reassigned the $pre_pse_ids to new $pre_pse_ids
      #$pre_pse_ids = $self->RetireArchivePlateFromFreezer($pss[0]->ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids);
      $pre_pse_ids = $self->RetireArchivePlateFromFreezer($pss[0]->ps_id, $bars_in, $bars_out, $emp_id, $options, $fpse_ids);
    }
  } elsif(! defined $fdesc) {
    #LSF: The box have not been checked out from the Freezer yet.
    #     You cannot expunge the tube.
    return;
  }

  my $new_pse_id = $self->BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'completed', 'successful', $emp_id, 0, $pre_pse_ids->[0]);
  return ($self->GetCoreError) if(!$new_pse_id);
  
  my $update_status = 'completed';
  my $update_result = 'successful';
  my $result =  $self->Process('UpdatePse', $update_status, $update_result, $pre_pse_ids->[0]);
  return 0 if(!$result);
  #LSF: Automatically complete the check out if someone try to expunge it before check out.
  foreach my $cipse (GSC::PSE->get(pse_id => [GSC::TppPSE->get(barcode => $bars_in->[0])], 
                ps_id => [GSC::ProcessStep->get(process_to => 'check in')], 
		pse_status => ['inprogress', 'scheduled'])) {
    $cipse->set(pse_status =>'completed',
             pse_result =>'successful',
             date_completed => App::Time->now,
	     ei_id_confirm => $emp_id);

  }
  my @pses = GSC::PSE->get(pse_id => [GSC::TppPSE->get(barcode => $bars_in->[0], prior_pse_id => 1)], 
                           ps_id => [GSC::ProcessStep->get(process_to => 'define primer tube')]);
  @pses = GSC::PSE->get(pse_id => [map { $_->prior_pse_id } grep { $_->prior_pse_id > 1 } GSC::TppPSE->get(pse_id => \@pses)], 
                        ps_id => [GSC::ProcessStep->get(process_to => 'request primer order')]);
  if(@pses) {
      my %ei = map { $_->ei_id => $_ } GSC::EmployeeInfo->get(ei_id => [$emp_id, $pses[0]->ei_id]);
      my %gu = map { $_->gu_id => $_ } GSC::User->get(gu_id => [map { $_->gu_id } values %ei]);
      my $name = ucfirst($gu{$ei{$emp_id}->gu_id}->first_name) . " " . ucfirst($gu{$ei{$emp_id}->gu_id}->last_name);
      my $email = $gu{$ei{$emp_id}->gu_id}->unix_login . "\@watson.wustl.edu";

      my $barcode = GSC::Barcode->get(barcode => $bars_in->[0]);
      my @pris = $barcode->get_primers;
      my $msg = qq($name expunged the following MP primers from the freezer system:) . "\n\n";
      $msg .= 'BARCODE      : ' . $bars_in->[0] . "\n";
      $msg .= 'PRIMERS      : ' . (join ',', map { $_->primer_name } @pris) . "\n";
      $msg .= 'REQUEST DATE : ' . $pses[0]->date_scheduled . "\n";
      $msg .= 'REQUESTOR    : ' . ucfirst($gu{$ei{$pses[0]->ei_id}->gu_id}->first_name) . ' ' . ucfirst($gu{$ei{$pses[0]->ei_id}->gu_id}->last_name) . ' (' . $gu{$ei{$pses[0]->ei_id}->gu_id}->unix_login . ")\n";
      $msg .= "\n\n";

      App::Mail->mail(
          To      =>"mp-primer\@watson.wustl.edu",
          From    =>"$name <$email>",
          Subject =>"MP Primer Expunged",
          Message =>$msg
      );
  }

  return [$new_pse_id];

}

=head2 isFreezerRackOrColumnOccupied

Is the freezer Rack Or Column Occupied?

=cut

sub isFreezerRackOrColumnOccupied {
  my $self = shift;
  my($barcode) = @_; 
  my $ei = GSC::EquipmentInformation->get(barcode => $barcode);
  unless($self->_get_all_occupied_slots($barcode)) {
    $self->{'Error'} = "$pkg: No occupied slot in $barcode!";
    return 0;
  }
  my $bar = GSC::Barcode->get(barcode => $barcode);
  my $desc = $bar->resolve_barcode_label;
  return $barcode unless($desc);
  return $desc;
}

=head2 expungeAll

Expunge the rack or column from storage

=cut
sub expungeAll {
  my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
  my @slots = $self->_get_all_occupied_slots($bars_in->[0]);
  return unless(@slots);
  my @pses;
  foreach my $slot (@slots) {
     my @content_barcodes = $slot->get_contents();
     unless(@content_barcodes == 1) {
       $self->{'Error'} = "Occupied slot [" . $slot->barcode . "|" . $slot->unit_name . "] " . (@content_barcodes ? "more than one content!" : "without content!");
       return;
     }
     my($fdesc, $fpse_ids) = $self->GetFreezerBarcodeDescToCheckout($content_barcodes[0]->barcode, $ps_id);
     my $result = $self->RetireArchivePlateFromFreezer($ps_id, [$content_barcodes[0]->barcode], $bars_out, $emp_id, $options, $fpse_ids);
     return unless($result);
     push @pses, @{$result};
  }
  return \@pses;
}

sub _get_all_occupied_slots {
  my $proto = shift;
  my $barcode = shift;
  my $ei = GSC::EquipmentInformation->get(barcode => $barcode);
  return unless($ei);
  my @eis;
  if($ei->equipment_description eq "freezer rack") {
    push @eis, $ei->get_parts;
  } else {
    push @eis, $ei;
  }
  my @slots;
  foreach my $e (@eis) {
    push @slots, grep { $_->equipment_status eq "occupied" } $e->get_parts;
  }
  return @slots;
}

1;

# $Header$
