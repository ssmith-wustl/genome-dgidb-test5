# -*-Perl-*-

##############################################
# Copyright (C) 2002 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

package TouchScreen::BiomekSql;

use strict;
use DbAss;
use TouchScreen::CoreSql;

#############################################################
# Production sql code package
#############################################################

require Exporter;


our @ISA = qw (Exporter AutoLoader);
our @EXPORT = qw ( );

my $pkg = __PACKAGE__;

#########################################################
# Create a new instance of the Biomek code so that you #
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
    
    $self->{'Biomek Setup'} = [{'Name' => 'FWD Reservoir',
				'Barcode' => undef,
				'Query'   => 'GetResevoirDesc',},
			       {'Name' => 'FWD',
				'Barcode' => undef,
				'Query'   => 'GetBrewDesc',}, 
			       {'Name' => 'REV Reservoir',
				'Barcode' => undef,
				'Query'   => 'GetResevoirDesc',}, 
			       {'Name' => 'REV',
				'Barcode' => undef,
				'Query'   => 'GetBrewDesc',}, 
			       {'Name' => 'Buddy',
				'Barcode' => undef,
				'Query'   => 'GetEmployeeDesc',}, 
			       ];
    
    
    $self->{'ActivePosition'} = 0;
    $self-> {'BossCheck'} = 0;

    $self->{'GetResevoirDesc'} = LoadSql($dbh, "select barcode_description, equinf_bs_barcode from barcode_sources, equipment_informations
                                 where barcode =  bs_barcode and 
                                 bs_barcode = ? and equ_equipment_description like ?", 'ListOfList');

    $self->{'GetBrewDesc'} = LoadSql($dbh, "select rn_reagent_name, batch_number from reagent_informations where bs_barcode = ? and
                             upper(rn_reagent_name) like upper(?)", 'ListOfList');
    $self->{'GetEmployeeDesc'} = LoadSql($dbh, "select unix_login from gsc_users where us_user_status = 'active' and bs_barcode = ?", "Single");

    $self -> {'GetReagentVector'} = LoadSql($dbh, "select distinct vec_vec_id from reagent_vector_linearizations, vector_linearizations, vectors
                                                       where vl_id = vl_vl_id and vec_vec_id = vec_id and
                                                       vector_name != 'unknown' and rn_reagent_name = ?", 'Single');
    $self -> {'GetActiveResevoirReagent'} = LoadSql($dbh, "select distinct rn_reagent_name, batch_number from process_step_executions, pse_equipment_informations,
                                               reagent_used_pses, reagent_informations, process_steps
                                               where 
                                               pse_id = pse_equipment_informations.pse_pse_id and 
                                               psesta_pse_status = 'inprogress' and
                                               ps_id = ps_ps_id and 
                                               ps_ps_id in (select ps_id from process_steps where (pro_process_to, gro_group_name) in (select pro_process, gro_group_name from
                                                            process_steps where ps_id = ?)) and
                                               equinf_bs_barcode = ? and
                                               reagent_used_pses.pse_pse_id = pse_id and
                                               RI_BS_BARCODE = bs_barcode and 
                                               upper(rn_reagent_name) like upper(?)", 'ListOfList');

    $self -> {'GetPreSetupPses'} = LoadSql($dbh, "select distinct pse_id from process_step_executions, pse_equipment_informations 
                                               where 
                                               pse_id = pse_pse_id and 
                                               psesta_pse_status = 'inprogress' and
                                               ps_ps_id in(select ps1.ps_id from process_steps ps1 
                                                           join process_steps ps2 on ps1.pro_process_to = ps2.pro_process_to 
                                                           where ps2.ps_id = ?) and
                                               equinf_bs_barcode in (?, ?)", 'List');

    $self->{'GetBuddyId'} = LoadSql($dbh, "select ei_id from employee_infos, gsc_users where 
                            gu_id = gu_gu_id and
                            gsc_users.us_user_status = 'active' and 
                            employee_infos.us_user_status = 'active' and 
                            bs_barcode = ? and
                            gro_group_name = (select gro_group_name from employee_infos where ei_id = ?)", 'Single');
   
    $self->{'EquipmentEvent'} = LoadSql($dbh,"insert into $schema.pse_equipment_informations (equinf_bs_barcode, pse_pse_id)values (?, ?)");
    $self->{'ReagentEvent'} = LoadSql($dbh,"insert into $schema.reagent_used_pses (RI_BS_BARCODE, pse_pse_id) values (?,?)");
    $self->{'CheckIfBoss'} = LoadSql($dbh,"select count(*) from $schema.bosses where gu_gu_id_boss in 
                                     (select gu_id from gsc_users where bs_barcode = ?)", 'Single');
	    
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
# Destroy a Biomek session #
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

sub CheckBiomekSetupInfo {

    my ($self, $barcode, $ps_id) = @_;
    my $pos = $self->{'ActivePosition'};
    if($pos >=5) {
	$self->{'Error'} = "$pkg: CheckBiomekSetupInfo() -> All setup information entered. Please confirm or restart.";
	return 0;
    }

    if(($barcode =~ /^empty/) && ($pos == 1)) {
	$self->{'ActivePosition'}++;
	$self->{'empty_count'} ++;
	return $barcode;
    }
    if(($barcode =~ /^empty/) && ($pos == 3) && ! ($self->{'empty_count'})) {
	$self->{'ActivePosition'}++;
	$self->{'empty_count'} ++;
	return $barcode;
    }
    
    my $info = $self->{'Biomek Setup'}->[$pos];
    
    my $name = $info->{'Name'};
    my $query = $info->{'Query'};
    
    my $desc;
    if($name eq 'Buddy') {
	$desc = $self -> {$query} -> xSql($barcode);
	$self -> {'Error'} = "$pkg: CheckBiomekSetupInfo() -> Could not find user information.";
    }
    elsif(($name eq 'FWD') || ($name eq 'REV')) {
	my $temp = $self -> {$query} -> xSql($barcode, "%$name%");
	$temp = $self->{$query} -> xSql($barcode, '%Premix%') if((! @$temp) && $name eq 'FWD');
	if(defined $temp->[0][0]) {
	    my $vec_id = $self -> {'GetReagentVector'} -> xSql($temp->[0][0]);
	    if($pos == 1) {
		$self -> {'ReagentVector'} = $vec_id;
	    }
	    elsif($self -> {'ReagentVector'} != $vec_id  && ! $self->{'empty_count'}) {
		$self->{'Error'} = "$pkg:  CheckBiomekSetupInfo() -> Reverse Brew does not have the same vector as Forward Brew.";
		return 0;
	    }

	    $desc = $temp->[0][0].' batch '.$temp->[0][1];
	}
	else {
	    $self -> {'Error'} = "$pkg: CheckBiomekSetupInfo() -> Brew not valid for this position.";
	}
    }
    elsif(($name eq 'FWD Reservoir') || ($name eq 'REV Reservoir')){
	my $temp = $self -> {$query} -> xSql($barcode, $name);
	if(defined $temp->[0][0]) {
	    if($pos == 0) {
		$self -> {'ParentMachine'} = $temp->[0][1];
	    }
	    elsif($self -> {'ParentMachine'} ne $temp->[0][1]) {
		$self->{'Error'} = "$pkg: CheckBiomekSetupInfo() -> 2nd Reservoir does not have the same parent equipment.";
		return 0;
	    }
	    
	    $desc = $temp->[0][0];  
	}
	else {
	    $self -> {'Error'} = "$pkg: CheckBiomekSetupInfo() -> Could not find resevoir information.";
	}
	
    }

    if(defined $desc) {
	$self->{'ActivePosition'}++;
	return ($desc);
    }

    return 0;

} #CheckBiomekSetupInfo

sub CheckBiomekAddInfo {

    my ($self, $barcode, $ps_id) = @_;
    my $pos = $self->{'ActivePosition'};
    if($pos >=3) {
	$self->{'Error'} = "$pkg: CheckBiomekAddInfo() -> All setup information entered. Please confirm or restart.";
	return 0;
    }

    my $desc;
    
    if($pos == 0) {
	my $temp = $self -> {'GetResevoirDesc'} -> xSql($barcode, '%');
	if(defined $temp->[0][0]) {
	    $desc = $temp->[0][0];
	    
	    my $direction = 'FWD';
	    if($desc =~ /REV/) {
		$direction = 'REV';
	    }
	    $temp = $self -> {'GetActiveResevoirReagent'} -> xSql($ps_id, $barcode, '%'.$direction.'%');
	    if(defined $temp->[0][0]) {
		$self -> {'ActiveReagent'} = $temp->[0][0];
		$self -> {'ActiveBatch'} = $temp->[0][1];
		$desc = $desc." ActiveReagent=$temp->[0][0] - $temp->[0][1]";
	    }
	    else {
		$desc = undef;
		$self->{'Error'} = "$pkg: CheckBiomekAddInfo() -> Could not find an active reagent.";
	    }
	}
	else {
	    $self -> {'Error'} = "$pkg: CheckBiomekAddInfo() -> Could not find resevoir information.";
	}
    }
    elsif($pos == 1) {
	
	my $temp = $self -> {'GetBrewDesc'} -> xSql($barcode, $self->{'ActiveReagent'});
	if(defined $temp->[0][0]) {
	    $desc = $temp->[0][0].' batch '.$temp->[0][1];
#	    if($self -> {'ActiveBatch'} ne $temp->[0][1]) {
#		$self-> {'BossCheck'} = 1;
#		$self-> {'BossCheck'} = 0;
#	    }
	}
	else {
	    $self -> {'Error'} = "$pkg: CheckBiomekAddInfo() -> Brew not valid for this position.";
	}
	
    }
    elsif($pos == 2) {
	$desc = $self -> {'GetEmployeeDesc'} -> xSql($barcode);
	$self -> {'Error'} = "$pkg: CheckBiomekSetupInfo() -> Could not find user information.";
#	if($self->{'BossCheck'}) {
#	    if($self->{'CheckIfBoss'}->xSql($barcode) == 0) {
#		$self -> {'Error'} = "$pkg: CheckBiomekSetupInfo() -> Setup Reagent Batch != Scan Reagent Batch, Buddy needs to be a Boss.";
#		$desc = undef;
#	    }
#	}
    }

    if(defined $desc) {
	$self->{'ActivePosition'}++;
	return ($desc);
    }

    return 0;

} #CheckBiomekAddInfo

################################################################################
#                                                                              #
#                              Output verification subroutines                 #
#                                                                              #
################################################################################


sub SetupBiomek {
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $status = 'inprogress';
    my $pse_result = '';

    my $resevoir_fwd = $bars_in->[0];
    my $reagent_fwd  = $bars_in->[1];
    my $resevoir_rev = $bars_in->[2];
    my $reagent_rev  = $bars_in->[3];
    my $buddy        = $bars_in->[4];

    my $dbh = $self->{'dbh'};
    my $schema = $self->{'Schema'};

    $pre_pse_ids =  $self -> {'GetPreSetupPses'} -> xSql($ps_id, $resevoir_fwd, $resevoir_rev);
    foreach my $pre_pse (@{$pre_pse_ids}) {
	my $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse);
	return ($self->GetCoreError) if(!$result);
    }

    my $buddy_id = $self->{'GetBuddyId'} -> xSql($buddy, $emp_id);
    if(!defined $buddy_id) {
	$self->{'Error'} = "$pkg: SetupBiomek() -> Could not find buddy employee id.";
	return 0;
    }
    
    if($buddy_id == $emp_id) {
	$self->{'Error'} = "$pkg: SetupBiomek() -> Buddy and user cannot be the same.";
	return  0;
    }


    my $new_pse_id =  $self->{'CoreSql'}->Process('GetNextPse');
    return (0) if(!$new_pse_id);
    
    my $result = $self->{'CoreSql'}->Process('InsertPseEvent', '0', $status, $pse_result, $ps_id, $emp_id, $new_pse_id, $buddy_id, 0, $pre_pse_ids->[0]);
    return (0) if(! $result);
    
    if(! ($reagent_fwd =~ /^empty/)) {
        $result = $self->{'EquipmentEvent'} -> xSql($resevoir_fwd, $new_pse_id);
        if(!$result) {
            $self->{'Error'} = "$pkg: AddBrewToBiomek() -> Could not insert resevoir/pse.";
            return 0;
        }
        $result = $self->{'ReagentEvent'} -> xSql($reagent_fwd, $new_pse_id);
        if(!$result) {
            $self->{'Error'} = "$pkg: AddBrewToBiomek() -> Could not insert forward reagent/pse.";
            return 0;
        }
    }
    
    if(! ($reagent_rev =~ /^empty/)) {
	$result = $self->{'EquipmentEvent'} -> xSql($resevoir_rev, $new_pse_id);
	if(!$result) {
	    $self->{'Error'} = "$pkg: AddBrewToBiomek() -> Could not insert resevoir/pse.";
	    return 0;
	}
	
	$result = $self->{'ReagentEvent'} -> xSql($reagent_rev, $new_pse_id);
	if(!$result) {
	    $self->{'Error'} = "$pkg: AddBrewToBiomek() -> Could not insert reverse reagent/pse.";
	    return 0;
	}
    }
    
    push(@{$pse_ids}, $new_pse_id);
    return $pse_ids;
} #SetupBiomek


sub AddBrewToBiomek {
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $status = 'completed';
    my $pse_result = 'successful';

    my $resevoir = $bars_in->[0];
    my $reagent  = $bars_in->[1];
    my $buddy        = $bars_in->[2];

    my $dbh = $self->{'dbh'};
    my $schema = $self->{'Schema'};

    my $buddy_id = $self->{'GetBuddyId'} -> xSql($buddy, $emp_id);
    if(!defined $buddy_id) {
	$self->{'Error'} = "$pkg: SetupBiomek() -> Could not find buddy employee id.";
	return 0;
    }
    
    if($buddy_id == $emp_id) {
	$self->{'Error'} = "$pkg: SetupBiomek() -> Buddy and user cannot be the same.";
	return  0;
    }

    my $new_pse_id =  $self->{'CoreSql'}->Process('GetNextPse');
    return (0) if(!$new_pse_id);
    
    my $result = $self->{'CoreSql'}->Process('InsertPseEvent', '0', $status, $pse_result, $ps_id, $emp_id, $new_pse_id, $buddy_id, 0, $pre_pse_ids->[0]);
    return (0) if(! $result);
	
    #update pse to set date completed
    $result = $self -> {'CoreSql'} -> Process('UpdatePse', $status, $pse_result, $new_pse_id);
    return ($self->GetCoreError) if(!$result);
   
    $result = $self->{'EquipmentEvent'} -> xSql($resevoir, $new_pse_id);
    if(!$result) {
	$self->{'Error'} = "$pkg: AddBrewToBiomek() -> Could not insert resevoir/pse.";
	return 0;
    }

    $result = $self->{'ReagentEvent'} -> xSql($reagent, $new_pse_id);
     if(!$result) {
	$self->{'Error'} = "$pkg: AddBrewToBiomek() -> Could not insert reagent/pse.";
	return 0;
    }
  

    push(@{$pse_ids}, $new_pse_id);
    return $pse_ids;
} #AddBrewToBiomek


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
