# -*-Perl-*-

##############################################
# Copyright (C) 2003 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

package TouchScreen::EstSql;

use strict;
use ConvertWell ':all';
use DBD::Oracle;
use DBD::Oracle qw(:ora_types);
use DBI;
use DbAss;
use TouchScreen::CoreSql;
use TouchScreen::TouchSql;
use TouchScreen::NewProdSql;
use TouchScreen::PrefinishSql;

#############################################################
# Production sql code package
#############################################################

require Exporter;


our @ISA = qw (Exporter AutoLoader);
our @EXPORT = qw ( );

my $pkg = __PACKAGE__;

#########################################################
# Create a new instance of the EstSql code so that you #
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

 
    $self->{'GetAvailSeqDna'} = LoadSql($dbh, qq/select distinct pcr_name, pse.pse_id from 
					pcr_product pcr, 
					pse_barcodes barx, dna_relationship dr, dna_pse sdx,
				    process_step_executions pse
				    where 
				    pcr.pcr_id = dr.parent_dna_id and 
				    dr.dna_id = sdx.dna_id and
				    barx.pse_pse_id = sdx.pse_id and
				    barx.pse_pse_id = pse.pse_id and
				    pse.psesta_pse_status = ? and 
				    barx.bs_barcode = ? and 
				    barx.direction = ?  and 
				    pse.ps_ps_id in 
				    (select ps_id from process_steps where  pro_process_to in
				     (select pro_process from process_steps where ps_id = ?) and      
				     purpose = ?)/, 'ListOfList');

    $self -> {'InsertArchives'} = LoadSql($dbh, "insert into archives 
	    (archive_number, available, gro_group_name, arc_id, ap_purpose)
	    values (?, ?, ?, ?, ?)");
    
    $self->{'platelist'} = ['aaa01', 'aaa02', 'aaa03'];
 
    $self->{'GetArchiveNumber'} = LoadSql($dbh, "select archive_number from archives where arc_id = ?", 'Single');
    $self->{'GetWellCount'} = LoadSql($dbh, "select well_count from plate_types where pt_id = ?", 'Single');
    $self -> {'GetSectorName'} = LoadSql($dbh, "select sector_name from sectors where sec_id = ?", 'Single');

 
   $self->{'GetPlId'} = LoadSql($dbh, "select pl_id from plate_locations where well_name = ? and 
                                    sec_sec_id = ? and pt_pt_id = ?", 'Single');

    $self->{'InsertSubclones'} = LoadSql($dbh, "insert into subclones
		            (subclone_name, lig_lig_id, sub_id, arc_arc_id) 
		            values (?, ?, ?, ?)");
    $self -> {'InsertSubclonesPses'} = LoadSql($dbh, "insert into subclones_pses
	    (pse_pse_id, sub_sub_id, pl_pl_id) 
	    values (?, ?, ?)");
    return $self;
} #new

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
# Destroy a PrefinishSql session #
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


#############################################
# Get the Barcode Description for a barcode # 
#############################################
sub CheckIfUsedAsInput{
    my ($self, $barcode) = @_;

    my $desc = $self->{'CoreSql'} -> CheckIfUsed($barcode, 'in');
    return ($self->GetCoreError) if(!$desc);
    return $desc;
    
    return $desc;
} #CheckIfUsedAsInput






################################################################################
#                                                                              #
#                              Output verification subroutines                 #
#                                                                              #
################################################################################


##########################################
#     Output verification Subroutines    #
##########################################
sub CheckIfUsedAsOutput {

    my ($self, $barcode) = @_;

    my $desc = $self->{'CoreSql'} -> CheckIfUsed($barcode, 'out');
    return ($self->GetCoreError) if(!$desc);
    return $desc;

} #CheckIfUsedAsOutput

#########################
# DataInfos Subroutines #
#########################
sub GetPlateName {

    my ($self, $ps_id, $desc, $barcode) = @_;

    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});

    my ($pso_id, $data, $lov) = $TouchSql -> GetPsoInfo($ps_id, $desc);
    
    $TouchSql -> destroy;

    $data = pop(@{$self->{'platelist'}});
    
    return ($pso_id, $data, $lov);

} #GetPlateName


############################################################################################
#                                                                                          #
#                         Confirm Subrotine Processes                                      #
#                                                                                          #
############################################################################################


sub ReceivePlate {
    
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_id=[];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $pre_pse_id = $pre_pse_ids->[0];

    my @sectors;   
    my $platename;

    my $purpose= 'production';
    my $plate_type = '384';
    push(@sectors, qw(a1 a2 b1 b2));

    my $lig_id = 218060;

    
    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', $plate_type);
    return 0 if($pt_id == 0);
        
    foreach my $bar_out (@{$bars_in}) {

	foreach my $sector (@sectors) {

	    my $sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', $sector);
	    return ($self->GetCoreError) if(!$sec_id);

	    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, undef, [$bar_out], $emp_id);
	    return ($self->GetCoreError) if(!$new_pse_id);

	    my $arc_id = $self -> GetNextArcId;
	    return 0 if(!$arc_id);
		
	    my $result1 = 0;
	    while($result1==0) {
		# Get next Archive
		my $ArchiveNumber = $self -> GetNextArchiveNumber('gsc');
		return 0 if (!$ArchiveNumber);

		# Insert New Archive number
		$result1 = $self -> InsertArchiveNumber($arc_id, $ArchiveNumber, 'NO', 'unknown', $purpose);
		#return 0 if (!$result);
	    }

	    # Generate Subclones
	    my $result = $self -> GenerateSubclonesAndLocations($new_pse_id, $lig_id, $arc_id, $pt_id, $sec_id);
	    return 0 if (!$result);

	    push(@{$pse_id}, $new_pse_id);
	}
    }

    return $pse_id;
  

}

#########################################
# Get the next available archive number #
#########################################
sub GetNextArcId {

    my ($self) = @_;
    my $arc_id = Query($self->{'dbh'}, "select arc_seq.nextval from dual");
    if($arc_id) {
	return $arc_id;
    }
    $self->{'Error'} = "$pkg: GetNextArcId()";

    return 0;
 
} #GetNextArcId

sub GetNextArchiveNumber {

    my ($self, $group) = @_;
    my $sql;
    my $NewArchiveNumber = 0;
    my $result = 0;
    my $dbh = $self ->{'dbh'};
    my $schema = $self->{'Schema'};

    my $db_query = $dbh->prepare(q{
	BEGIN 
	    :arch_num := gsc.ArchiveNumber.GetNextArchiveNumber(:group); 
	END;
	
    });

    
    
    my $db_answer;		

    $db_query->bind_param_inout(":arch_num", \$NewArchiveNumber, 5);
    $db_query->bind_param(":group", $group, {ora_type => ORA_VARCHAR2});
    $db_query->execute;
    

    if(defined $DBI::errstr){
	$self->{'Error'} = $DBI::errstr;
    }
    else {
	return $NewArchiveNumber;
    }
    return $result;
} #GetNextArchiveNumber
###############################
# Insert a new archive number #
###############################
sub InsertArchiveNumber {

    my ($self, $arc_id, $ArchiveNumber, $AvailStatus, $group, $purpose) = @_;
    
    # Insert into archive numbers table
    
    my $result = $self -> {'InsertArchives'} -> xSql($ArchiveNumber, $AvailStatus, $group, $arc_id, $purpose);

    if($result) {
	return $arc_id;
    }
    
    $self->{'Error'} = "$pkg: InsertArchiveNumber() -> Could not insert archive number where archive_number = $ArchiveNumber, status = $AvailStatus, group = $group, arc_id = $arc_id.";


    return 0;
} #InsertArchiveNumber



#################################################################
# Generate a new subclones and update subclone/locations tables #
#################################################################
sub GenerateSubclonesAndLocations {

    my ($self, $pse_id, $lig_id, $arc_id, $pt_id, $sec_id) = @_;
    
    my @rows  = qw(a b c d e f g h);
    my ($i, $j);

    my $ArchiveNumber = $self->GetArchiveNumber($arc_id);
    return 0 if($ArchiveNumber eq '0');
    
    my $well_count = $self->GetWellCount($pt_id);
    return 0 if($well_count == 0);
    
    my $sector = $self -> GetSectorName($sec_id); 
    return 0 if(!$sector);
		
    for ($j=0;$j<=$#rows;$j++) {
	for($i=1;$i<=12;$i++) {
	    my $well;
	    
	    # generate well
	    if ($i < 10) {
		$well = $rows[$j].'0'.$i;
	    }
	    else {
		$well = $rows[$j].$i;
	    }
	    
	    # Build subclone name
	    my $subclone = $ArchiveNumber.$well;
	    
	    # get next sub_id
	    my $sub_id = $self -> GetNextSubId;
	    return 0 if(!$sub_id);

	    # determine plate location
	    if($well_count == 384) {
		$well = &ConvertWell::To384 ($well, $sector);
	    }
		
	    my $pl_id = $self->GetPlId($well, $sec_id, $pt_id);
	    return 0 if($pl_id eq '0');

	    # insert subclone
	    my $result = $self -> InsertSubclones($subclone, $lig_id, $sub_id, $arc_id, $pse_id, $pl_id);
	    return 0 if(!$result);
	    
	    
	    # insert subclones_pses
	    $result = $self -> InsertSubclonesPses($pse_id, $sub_id, $pl_id);
	    return 0 if(!$result);
	}
    }

    return 1;
 
} #GenerateSubclonesAndLocations



##################################
# Get archive number from arc_id #
##################################
sub GetArchiveNumber {

    my ($self, $arc_id) = @_;
    
    my $arc_num = $self->{'GetArchiveNumber'} -> xSql($arc_id);
    
    if(defined $arc_num) {
	return $arc_num;
    }
    
    $self->{'Error'} = "$pkg: GetArchiveNumber() -> Could not get archive number from arc_id.";

    return 0;
} #GetArchiveNumber

#############################
# Get Well count from pt_id #
#############################
sub GetWellCount {

    my ($self, $pt_id) = @_;

    my $well_count = $self->{'GetWellCount'} ->xSql($pt_id);

    if(defined $well_count) {
	return $well_count;
    }
    
    $self->{'Error'} = "$pkg: GetWellCount() -> Could not determine well count for $pt_id.";

} #GetWellCount


##################################
# Get the sector name for sec_id #
##################################
sub GetSectorName {

    my ($self, $sec_id) = @_;

    my $sector = $self -> {'GetSectorName'} -> xSql($sec_id); 
    
    if(defined $sector) {
	return $sector;
    }

    $self->{'Error'} = "$pkg: GetSectorName() -> Could not find sector name for $sec_id.";
    return 0;

} #GetSectorName

#######################################
# Get the next sub_id sequence number #
#######################################
sub GetNextSubId {

    my ($self) = @_;
    my $sub_id = Query($self->{'dbh'}, "select sub_seq.nextval from dual");
    if($sub_id) {
	return $sub_id;
    }
    $self->{'Error'} = "$pkg: GetNextSubId() -> Could not get next sub_id.";

    return 0;
 
} #GetNextSubId

####################################################
# Get the plate id from the well, sec_id and pt_id #
####################################################
sub GetPlId {

    my ($self, $well, $sec_id, $pt_id) = @_;
    my $pl_id = $self->{'GetPlId'} ->xSql($well, $sec_id, $pt_id);
    if(defined $pl_id) {
	return $pl_id;
    }
    
    $self->{'Error'} = "$pkg: GetPlId() -> Could not find pl_id where $well, $sec_id, $pt_id.";
    return 0;
} #GetPlId

 
sub InsertSubclones {

    my($self, $subclone, $lig_id, $sub_id, $arc_id, $pse_id, $dl_id) = @_;
    #subclone_name, lig_lig_id, sub_id, arc_arc_id
    my $result = $self->{'InsertSubclones'}->xSql($subclone, $lig_id, $sub_id, $arc_id);

    if($result) {

	return $result;
    }

    $self->{'Error'} = "$pkg: InsertSubclones() -> $subclone, $lig_id, $sub_id, $arc_id.";
}
#################################################################
# Insert an sub_id, pse_id, pl_id into the subclones_pses table #
#################################################################
sub InsertSubclonesPses {

    my ($self, $pse_id, $sub_id, $pl_id) = @_;

    my $result = $self -> {'InsertSubclonesPses'} -> xSql($pse_id, $sub_id, $pl_id);
    if($result) {
	return $result;
    }
    
    $self->{'Error'} = "$pkg: InsertSubclonesPses() -> Could not insert $pse_id, $sub_id, $pl_id";
    return 0;
} #InsertSubclonesPses

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
