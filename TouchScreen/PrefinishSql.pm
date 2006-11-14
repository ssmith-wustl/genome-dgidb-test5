# -*-Perl-*-

##############################################
# Copyright (C) 2001 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

package TouchScreen::PrefinishSql;

use strict;
use ConvertWell;
use DBD::Oracle;
use DBD::Oracle qw(:ora_types);
use DBI;
use DbAss;
use TouchScreen::CoreSql;
use TouchScreen::TouchSql;

#############################################################
# Production sql code package
#############################################################

require Exporter;

our @ISA = qw(TouchScreen::CoreSql TouchScreen::NewProdSql);
our @EXPORT = qw ( );

my $pkg = __PACKAGE__;

#########################################################
# Create a new instance of the PrefinishSql code so that you #
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

    $self = $class->SUPER::new( $dbh, $schema);
#    $self->{'CoreSql'} = TouchScreen::CoreSql->new($dbh, $schema);
#    $self -> {'GetAvailSubclonePf'} = LoadSql($dbh,  "select distinct pse.pse_id from 
#               pse_barcodes barx, 
#               process_step_executions pse,
#               subclones_pses subx
#               where 
#                   barx.pse_pse_id = pse.pse_id and
#                   pse.pse_id = subx.pse_pse_id and 
#                   pse.psesta_pse_status = ? and 
#               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
#               (select ps_id from process_steps where pro_process_to in
#               (select pro_process from process_steps where ps_id = ?) and      
#                purpose = ?)", 'List');

#    $self -> {'GetAvailBarcode'} = LoadSql($dbh,  "select distinct pse.pse_id from 
#               pse_barcodes barx, 
#               process_step_executions pse
#               where 
#                   barx.pse_pse_id = pse.pse_id and
#                   pse.psesta_pse_status = ? and 
#                   barx.bs_barcode = ? and 
#                   barx.direction = ? and pse.ps_ps_id in 
#                   (select ps_id from process_steps where pro_process_to in
#                   (select pro_process from process_steps where ps_id = ?) and      
#                   purpose = ?)", 'List');

    $self -> {'GetAvailOligoPlate'} = LoadSql($dbh,  "select distinct pse.pse_id from 
               pse_barcodes barx, 
               process_step_executions pse,
               process_steps
               where 
                   ps_id = ps_ps_id and
                   barx.pse_pse_id = pse.pse_id and
                   pse.psesta_pse_status = 'inprogress' and 
                   barx.bs_barcode = ? and 
                   barx.direction = 'in' and pro_process_to = 'checkin oligo plate'", 'Single');
    
    $self -> {'GetAvailPrimerPlate'} = LoadSql($dbh,  qq/select distinct pse.pse_id from 
                                               pse_barcodes barx, 
                                               process_step_executions pse,
                                               process_steps
                                               where 
                                               ps_id = ps_ps_id and
                                               barx.pse_pse_id = pse.pse_id and
                                               barx.bs_barcode = ? and 
                                               ((pse.psesta_pse_status = 'inprogress'
                                                 and barx.direction = 'out' 
                                                 and pro_process_to = 'rearray oligo')
                                                OR 
                                                (pse.psesta_pse_status = 'inprogress'
                                                 and barx.direction = 'in' 
                                                 and pro_process_to = 'checkin oligo plate'))
                                                
                                               /, 'List');

    $self->{'GetInputBarcodeWithPse'} = LoadSql($dbh,qq/select pb2.bs_barcode from pse_barcodes pb2
                                                join pse_barcodes pb1 on pb1.pse_pse_id = pb2.pse_pse_id
                                                where
                                                pb2.direction = 'in'
                                                and pb1.direction = 'out'
                                                and pb1.bs_barcode = ?
                                                and pb1.pse_pse_id = ?

                                                /, 'Single');

    $self->{'GetInputBarcodeWithPse2'} = LoadSql($dbh,qq/                                   select distinct pb2.bs_barcode from pse_barcodes pb2
                                                 join pse_barcodes pb1 on pb1.pse_pse_id = pb2.pse_pse_id
                                                 join dna_pse dp on dp.pse_id = pb1.pse_pse_id
                                                 where
                                                 pb2.direction = 'in'
                                                 and pb1.direction = 'out'
                                                 and pb1.bs_barcode = ?
                                                 and dp.dna_id in (select dr.parent_dna_id from dna_pse dp1
                                                 	                 join dna_relationship dr on dr.dna_id = dp1.dna_id
                                                                   where 
                                                                   dp1.pse_id = ?)
                                                 
                                                 /, 'Single');

#    $self->{'GetAvailSeqDnaPf'} = LoadSql($dbh, "select distinct pse.pse_id from 
#               pse_barcodes barx, seq_dna_pses sdx,
#               process_step_executions pse
#               where 
#                  barx.pse_pse_id = sdx.pse_pse_id and
#                  barx.pse_pse_id = pse.pse_id and
#                  pse.psesta_pse_status = ? and 
#                  barx.bs_barcode = ? and 
#                  barx.direction = ? and 
#                  pse.ps_ps_id in 
#                      (select ps_id from process_steps where  pro_process_to in
#                      (select pro_process from process_steps where ps_id = ?) and      
#                      purpose = ?)", 'List');
    

#    $self->{'InsertSequencedDnas'} = LoadSql($dbh, "insert into sequenced_dnas
#		    (sub_sub_id, pri_pri_id, dc_dc_id, enz_enz_id, seqdna_id) 
#		    values (?, ?, ?, ?, ?)");
    
#    $self->{'GetPlId'} = LoadSql($dbh, "select pl_id from plate_locations where well_name = ? and 
#                                    sec_sec_id = ? and pt_pt_id = ?", 'Single');
    
#    $self -> {'InsertSubclonesPses'} = LoadSql($dbh, "insert into subclones_pses
#	    (pse_pse_id, sub_sub_id, pl_pl_id) 
#	    values (?, ?, ?)");

    
#    $self->{'InsertSeqDnaPses'} = LoadSql($dbh,  "insert into seq_dna_pses
#	    (pse_pse_id, seqdna_seqdna_id, pl_pl_id) 
#	    values (?, ?, ?)");

    $self -> {'GetSubIdPlIdFromSubclonePse'} = LoadSql($dbh, "select  distinct sub_sub_id, well_name, pl_id  
               from pse_barcodes pbx, subclones_pses scx, plate_locations pl
               where pbx.bs_barcode = ? and pbx.direction = 'out' and 
               pl.pl_id = scx.pl_pl_id and 
               pbx.pse_pse_id = scx.pse_pse_id and 
               scx.pse_pse_id = ? order by pl_id", 'ListOfList');
    
     $self -> {'GetSeqDnaIdPlIdFromSeqDnaPse'} = LoadSql($dbh, "select distinct seqdna_seqdna_id, well_name, pl_id  
               from pse_barcodes pbx, seq_dna_pses scx, plate_locations pl
               where pbx.bs_barcode = ? and pbx.direction = 'out' and 
               pl.pl_id = scx.pl_pl_id and 
               pbx.pse_pse_id = scx.pse_pse_id and 
               seqdna_seqdna_id in (select seqdna_seqdna_id from seq_dna_pses where pse_pse_id = ?)", 'ListOfList');
    

#    $self->{'GetBarcodeDesc'} = LoadSql($dbh,"select barcode_description from barcode_sources where barcode = ?", 'Single');
#    $self -> {'Reagent Name'} = LoadSql($dbh, "select rn_reagent_name from reagent_informations where bs_barcode = ?", 'Single');
    
    
    $self->{'GetBarcodeSubPlPse'} = LoadSql($dbh, "select sub_sub_id, pl_pl_id from pse_barcodes pb, subclones_pses sp, process_step_executions where 
				      pb.pse_pse_id = pse_id and sp.pse_pse_id = pse_id and direction = 'out'
                                      and bs_barcode = ?  and psesta_pse_status = ? order by pl_pl_id", 'ListOfList');
    
    $self->{'GetSeqDnaPlIdInBarcode'}     = LoadSql($dbh, "select seqdna_seqdna_id, pl_pl_id from pse_barcodes pb, seq_dna_pses sp, process_step_executions where 
				      pb.pse_pse_id = pse_id and sp.pse_pse_id = pse_id and direction = 'out'
                                      and bs_barcode = ? order by pl_pl_id", 'ListOfList');

    $self -> {'ScanOligoPlate'} =0;
    $self -> {'DnaToPickRelation'} = {};
    
    
    $self -> {'GetPreBarPse'} = LoadSql($dbh, "select bs_barcode, pse_pse_id from pse_barcodes where direction = 'in' and pse_pse_id in (
                                                       select pse_pse_id from pse_barcodes where bs_barcode = ? and direction = 'out')", 'ListOfList');
    
    $self->{'GetAllSetup'} = LoadSql($dbh, qq/select distinct pb.bs_barcode, ds.dna_id, sp.pl_pl_id, pri_pri_id, dc_dc_id, enz_enz_id, ds_id 
    from 
       direct_seq_pses dp, direct_seq ds, pse_barcodes pb, subclones_pses sp
    where 
       pb.bs_barcode = ? and direction = 'out' and 
       sp.sub_sub_id = ds.dna_id and
       sp.pse_pse_id = pb.pse_pse_id and
       dp.pse_pse_id = pb.pse_pse_id and 
       ds_ds_id = ds_id/, 'ListOfList');
    $self -> {'GetPreBarPseInfo'} = LoadSql($dbh, qq/select 
pb.bs_barcode, pse.pse_id 
from process_steps ps, process_step_executions pse, pse_barcodes pb 
where 
  pse.pse_id = pb.pse_pse_id 
and 
  ps.ps_id = pse.ps_ps_id 
and 
  ps.pro_process_to = 'pick targeted subclones'
and
  pb.direction = 'out'
and
  pse.pse_id in (select pse_id from process_step_executions 
start with pse_id in (select pse_pse_id from pse_barcodes where bs_barcode = ? 
) connect by pse_id = prior prior_pse_id)/, 'ListOfList');
    
    $self -> {'CheckProcess'} = LoadSql($dbh, "select distinct pro_process_to from process_steps where ps_id in (select ps_ps_id from 
                                                       process_step_executions where pse_id = ?)", 'Single');
    
    $self -> {'PrefinishDyeChem'} = LoadSql($dbh, "select distinct dyetyp_dye_name, dc_id, enzyme_name, enz_id, pd_primer_direction, primer_type from 
                                                   direct_seq_pses dp, direct_seq, pse_barcodes pb, enzymes,
                                                   primers, dye_chemistries where bs_barcode = ? and direction = 'out' and
                                                   pb.pse_pse_id = dp.pse_pse_id and ds_ds_id = ds_id and pri_pri_id = pri_id and
                                                   dc_dc_id = dc_id and enz_enz_id = enz_id", 'ListOfList');
#    $self -> {'GetSubIdFromSubclone'} = LoadSql($dbh, qq/select sub_id from subclones where subclone_name = ?/, 'Single');
#    $self -> {'GetPriIdFromPrimer'} = LoadSql($dbh, qq/select pri_id from primers where primer_name = ?/, 'Single');
    
#    $self -> {'InsertDirectSeq'} = LoadSql($dbh, qq/insert into direct_seq 
#					       (enz_enz_id, pri_pri_id, dc_dc_id, sub_sub_id, seqmgr_directory, ds_id, trace_name) 
#					       values 
#					       (?, ?, ?, ?, ?, ?, ?)/);


#    $self -> {'InsertDirectSeqPses'} = LoadSql($dbh,  qq/insert into direct_seq_pses (ds_ds_id, pse_pse_id) values (?, ?)/);
    
    $self -> {'PrefinishDsDcEnzPriIds'} = LoadSql($dbh, qq/select distinct ds_id, dc_dc_id, enz_enz_id, pri_pri_id from 
						      direct_seq_pses dp, direct_seq ds, pse_barcodes pb, subclones_pses sp
						      where bs_barcode = ? and direction = 'out' and sp.sub_sub_id = ds.dna_id and
						      sp.sub_sub_id = ? and pl_pl_id = ? and ds.pri_pri_id = ? and 
						      ds.dc_dc_id in (select dc_id from dye_chemistries where 
						      DYETYP_DYE_NAME like ?) and ds.enz_enz_id = ? and
						      sp.pse_pse_id = pb.pse_pse_id and
						      pb.pse_pse_id = dp.pse_pse_id and ds_ds_id = ds_id/, 'ListOfList');
    
    $self -> {'GetSubPlIdsFromBarProcess'} = LoadSql($dbh, qq/select sub_sub_id, pl_pl_id from 
							 subclones_pses sp, pse_barcodes pb, process_step_executions, process_steps where 
							 sp.pse_pse_id = pb.pse_pse_id and direction = 'out' and bs_barcode = ? and 
							 pse_id = pb.pse_pse_id and ps_ps_id = ps_id and pro_process_to = ?/, 'ListOfList');
    
    $self->{'GetBarcodeSubPlWellPse'} = LoadSql($dbh, qq/select sub_sub_id, pl_pl_id, well_name 
						    from process_steps, pse_barcodes pb, subclones_pses sp, process_step_executions,
						    plate_locations pl where ps_ps_id = ps_id and 
						    pb.pse_pse_id = pse_id and sp.pse_pse_id = pse_id and direction = ? and pl.pl_id = sp.pl_pl_id and 
						    bs_barcode = ?  and psesta_pse_status = ? and (pr_pse_result = 'successful' or pr_pse_result is NULL) and
						    pro_process_to = ?  order by pl_pl_id/, 'ListOfList');

    $self->{'GetElutionDnaDlPse'} = LoadSql($dbh, qq/select dna_id, dl_id from 
					    pse_barcodes pb, dna_pse dp, process_step_executions pse, 
					    process_steps where 
					    ps_id = pse.ps_ps_id and
					    pb.pse_pse_id = pse.pse_id and 
					    dp.pse_id = pse.pse_id and 
					    direction = 'in'and 
					    bs_barcode = ?  and 
					    psesta_pse_status = 'completed' and
					    pr_pse_result = 'successful'  and
					    pro_process_to = 'verify growths' 
					    order by dl_id/, 'ListOfList');
    

$self -> {'GetAvailOligoOutInprogress'} =  LoadSql($dbh, qq{select /*+ RULE */
								distinct dsp.pri_pri_id, pse.pse_id,  dsp.dl_id, dsp.dna_id, bs_barcode, direction, dl.location_name  , pse.psesta_pse_status, ps.ps_id, pro_process, pro_process_to, p.primer_name
							  from 
							  	process_steps ps, process_step_executions pse, custom_primer_pse dsp, pse_barcodes pb, dna_location dl, primers p
							  where 
							  pb.pse_pse_id = dsp.pse_pse_id and
							  pse.pse_id = dsp.pse_pse_id and							  
							  ps.ps_id = pse.ps_ps_id and
							  p.pri_id = dsp.pri_pri_id and
							  direction = ? and
							  bs_barcode = (
							  select distinct pb.bs_barcode from 
							      process_steps ps, pse_barcodes pb, process_step_executions pse
							  where
								  pse.pse_id = pb.pse_pse_id and
        							   ps.ps_id = pse.ps_ps_id and
							  bs_barcode = ? and
							  pse.PSESTA_PSE_STATUS = 'inprogress'
							  and ps.pro_process_to in (select pro_process from process_steps where ps_id = ?))
							  and dl.dl_id = dsp.dl_id}, 'ListOfList');


    $self -> {'CheckBarcodeQuadrant'} =  LoadSql($dbh, qq/select distinct s.sector_name
                                                       from
                                                       pse_barcodes pb1
                                                       join pse_barcodes pb2 on pb2.pse_pse_id = pb1.pse_pse_id
                                                       join pse_barcodes pb3 on pb3.bs_barcode = pb2.bs_barcode
                                                       join custom_primer_pse cpp on cpp.pse_pse_id = pb3.pse_pse_id
                                                       join custom_primer_pse cpp2 on cpp2.pse_pse_id = pb1.pse_pse_id
                                                       join dna_location dl on dl.dl_id = cpp2.dl_id
                                                       join sectors s on s.sec_id = dl.sec_id
                                                       join (select dp.dna_id, dp.dl_id
                                                             from 
                                                             pse_barcodes pb 
                                                             join process_step_executions pse on pse.pse_id = pb.pse_pse_id
                                                             join process_steps ps on ps.ps_id = pse.ps_ps_id
                                                             join dna_pse dp on dp.pse_id = pb.pse_pse_id
                                                             where
                                                             ps.pro_process_to in ('elution', 'dna purification')
                                                             and pb.direction = 'out'
                                                             and dl_id = 1                    
                                                             and pb.bs_barcode = ?
                                                             ) x on x.dna_id = cpp.dna_id and x.dl_id = cpp.dl_id
                                                                          where
                                                       pb2.direction = 'in'
                                                       and pb3.direction = 'out'
                                                       and pb1.bs_barcode like '2s%'/, 'ListOfList');
                                                                          
							  
#    $self->{'InsertDirSeqDna'} = LoadSql($dbh, qq/insert into dir_seq_dnas
#					     (seqdna_seqdna_id, ds_ds_id) 
#					     values (?, ?)/);
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
    $self->{'Error'} = $self->{'Error'};
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

    my $desc = $self -> CheckIfUsed($barcode, 'in');
    return ($self->GetCoreError) if(!$desc);
    return $desc;
    
    return $desc;
} #CheckIfUsedAsInput


sub GetAvailSubclonesOutInprogressPf {

    my ($self, $barcode, $ps_id) = @_;

    #my ($result, $pses) = $self -> GetAvailSubclonePf($barcode, $ps_id, 'inprogress', 'out', 'Directed Sequencing');
    my ($result, $pses) = $self -> GetAvailBarcodeOutInprogress($barcode, $ps_id);

    return ($result, $pses);

}

sub GetAvailArchiveTargetedSubclones {


    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailBarcodeInInprogress($barcode, $ps_id);
    
    # Make sure it has not alread been archived
    if($result) {

        my $pses = App::DB->dbh->selectrow_array(qq/select distinct pse.pse_id from process_steps ps
                                                 join process_step_executions pse on pse.ps_ps_id = ps.ps_id
                                                 join pse_barcodes pb on pb.pse_pse_id = pse.pse_id
                                                 where
                                                 pb.direction = 'in'
                                                 and ps.pro_process_to= 'archive targeted subclones'
                                                 and pb.bs_barcode= '$barcode'/);

        if($pses) {
            $self->{'Error'} = "$pkg: GetAvailArchiveTargetedSubclones() -> plate has already been archived.";
            return;
        }
    }

    return ($result, $pses);
}




#sub GetAvailVerifyGrowths{

#    my ($self, $barcode, $ps_id) = @_;


#    my ($result, $pses) = $self -> GetAvailSubclonePf($barcode, $ps_id, 'inprogress', 'out', 'Directed Sequencing');
	
    
#    $self -> {'Error'} = "$pkg: GetAvailVerifyGrowths() -> There are still inputs plates scheduled for this plate = $barcode";
    
#    return ($result, $pses);
#}

#sub GetAvailSubclonesInInprogressPf {

#    my ($self, $barcode, $ps_id) = @_;

#    my ($result, $pses) = $self -> GetAvailSubclonePf($barcode, $ps_id, 'inprogress', 'in', 'Directed Sequencing');

#    return ($result, $pses);

#}


#################################
# get archive in subclones pses #
#################################
#sub GetAvailSubclonePf {

#    my ($self, $barcode, $ps_id, $status, $direction, $purpose) = @_;

#    my $dbh = $self -> {'dbh'};
#    my $schema = $self -> {'Schema'};
    
						
#    my $lol = $self -> {'GetAvailSubclonePf'} ->xSql($status, $barcode, $direction, $ps_id, $purpose);
    
#    if(defined $lol->[0]) {
#	my $pses = [];
#	for my $i (0 .. $#{$lol}) {
#	    push(@{$pses}, $lol->[$i]);
#	}
	
#	my $desc=$self->{'GetBarcodeDesc'} ->xSql($barcode);
#	return ($desc, $pses);
#    }
	
#    $self->{'Error'} = "$pkg: GetAvailSubclonePf() -> Could not find barcode description information for barcode = $barcode, ps_id = $ps_id, status = $status.";
    
	
#    return 0;

#}


 
#################################
#################################
#sub GetAvailBarcode {

#    my ($self, $barcode, $ps_id, $status, $direction, $purpose) = @_;

#    my $pses = $self -> {'GetAvailBarcode'} ->xSql($status, $barcode, $direction, $ps_id, $purpose);
    
#    if(defined $pses->[0]) {
#	my $desc=$self->{'GetBarcodeDesc'} ->xSql($barcode);
#	return ($desc, $pses);
#    }
	
#    $self->{'Error'} = "$pkg: GetAvailBarcode() -> Could not find barcode description information for barcode = $barcode, ps_id = $ps_id, status = $status.";
    
	
#    return 0;

#}

#################################
#################################
#sub GetAvailInInprogressPf{

#    my ($self, $barcode, $ps_id) = @_;

#    my ($result, $pses) = $self -> GetAvailBarcode($barcode, $ps_id, 'inprogress', 'in', 'Directed Sequencing');
    
#    return ($result, $pses);

#}

#sub GetAvailForClaimBead {

#    my ($self, $barcode, $ps_id) = @_;

#    my ($result, $pses) = $self -> GetAvailSubclonePf($barcode, $ps_id, 'inprogress', 'in', 'Directed Sequencing');

#    return ($result, $pses);

#}



sub GetAvailPrefinishSequence {

    my ($self, $barcode, $ps_id) = @_;

    #my ($result, $pses) = $self -> GetAvailSubclonePf($barcode, $ps_id, 'inprogress', 'out', 'Directed Sequencing');
    my ($result, $pses) = $self -> GetAvailBarcodeOutInprogress($barcode, $ps_id);
    
    my $dbh = $self->{'dbh'};
    if($result) {

        my $jpse = "\'". join("\',\'", @$pses)."\'";

        my $dc_sql = qq/ 
            select distinct  p.primer_name || '  '|| dc.dyetyp_dye_name  from 
            pse_barcodes pb2 
            join process_step_executions pse on pse.pse_id = pb2.pse_pse_id
            join process_steps ps on ps.ps_id = pse.ps_ps_id
            join direct_seq_pses dsp on dsp.pse_pse_id = pse.pse_id
            join direct_seq ds on ds.ds_id = dsp.ds_ds_id
            join primers p on p.pri_id = ds.pri_pri_id 
            join dye_chemistries dc on dc.dc_id = ds.dc_dc_id
            where
            pb2.bs_barcode in (
                               select pb.bs_barcode
                               from 
                               pse_barcodes pb 
                               where 
                               pb.pse_pse_id in ($jpse)
                               and pb.direction = 'in')
            and pb2.direction = 'out'
            and ps.pro_process_to = 'pick targeted subclones'
            /;
        my $dc_primer = App::DB->dbh->selectrow_array($dc_sql);
     
        if($dc_primer) {
            my $desc = $barcode.' '.$dc_primer;
            return ($desc, $pses);
        }
        else {
            $self->{'Error'} = "Could not determine primer / dye chem";
            return;
        }
    }
    
    return($result, $pses);
    
}

sub GetAvailPrefinishOligoSequence384 {

    my ($self, $barcode, $ps_id) = @_;

    my $dbh = $self->{'dbh'};
    if(($barcode =~ /^22/) && (!$self -> {'ScanOligoPlate'})) {


        my ($result, $pses) = $self -> GetAvailBarcodeOutInprogress($barcode, $ps_id);
	
	if($result) {

	    my ($ds_barcode, %rinfo) = $self->GetDirSeqInfo($barcode); # Review for schema changes
	    
	    
	    if($rinfo{'primer_type'} eq 'custom') {
		$self -> {'ScanOligoPlate'} = 1;
		$self -> {'DnaPlate'} = $barcode;
		my $desc = $rinfo{'dye_name'}.' '.$rinfo{'primer_direction'}.' '.$rinfo{'primer_type'};
		return ($desc, $pses);
	    }
	    
	}
    
	return($result, $pses);
    }
    else {
	
	my $result = $self -> {'GetAvailPrimerPlate'} -> xSql($barcode);

	if($result) {
	    my $subclones = $self -> {'GetSubPlIdsFromBarProcess'} -> xSql($self->{'DnaPlate'}, 'rearray dna');
	    
	    #LSF: New way.
	    my @pbs = GSC::PSEBarcode->get(barcode => $barcode, direction => 'out');
	    my @cpps = GSC::CustomPrimerPSE->get(pse_id => \@pbs, dna_id => [ map { $_->[0] } @$subclones], dl_id =>  [ map { $_->[1] } @$subclones]);
	    my %data;
	    foreach my $cpp (@cpps) {
	      push @{$data{$cpp->dna_id}->{$cpp->dl_id}}, $cpp;
	    }
	    #LSF: End New way.
	    foreach my $subclone (@{$subclones}) {
	      my $count = $data{$subclone->[0]}->{$subclone->[1]} ? scalar @{$data{$subclone->[0]}->{$subclone->[1]}} : 0;
	      if($count != 1) {
		  $self -> {'Error'} = "$pkg: GetAvailPrefinishOligoSequence -> Oligo plate does not match dna plate subclones.";
		  return (0);
	      }	    
	    }
=cut
	    my $oligo_exists = LoadSql($dbh, qq/select count(pri_pri_id) from custom_primer_pse cp, pse_barcodes pb where direction = 'out' and
					   bs_barcode = '$barcode' and dna_id = ? and dl_id = ? and cp.pse_pse_id = pb.pse_pse_id/, 'Single');
	    foreach my $subclone (@{$subclones}) {
		my $count = $oligo_exists -> xSql($subclone->[0], $subclone->[1]);
		if($count != 1) {
		    #print "$subclone->[0], $subclone->[1]\n";
		    $self -> {'Error'} = "$pkg: GetAvailPrefinishOligoSequence -> Oligo plate does not match dna plate subclones.";
		    return (0);
		}
	    }
=cut	    
	    $self -> {'DnaPlate'} = '';
	    $self -> {'ScanOligoPlate'} = 0;
	    return('384 well oligo plate', undef);
	}
	else {
	    $self -> {'Error'} = "$pkg: GetAvailPrefinishOligoSequence() -> Oligo plate not checked in.";
	    return 0;
	}
    }
   

}


sub GetAvailPrefinishOligoSequence {

    my ($self, $barcode, $ps_id) = @_;

    my $dbh = $self->{'dbh'};
    if(($barcode =~ /^15/) && (!$self -> {'ScanOligoPlate'})) {

	#my ($result, $pses) = $self -> GetAvailSubclonePf($barcode, $ps_id, 'inprogress', 'out', 'Directed Sequencing');
        my ($result, $pses) = $self -> GetAvailBarcodeOutInprogress($barcode, $ps_id);
	
	if($result) {

	    my ($ds_barcode, %rinfo) = $self->GetDirSeqInfo($barcode); # Review for schema changes
	    
	    
	    if($rinfo{'primer_type'} eq 'custom') {
		$self -> {'ScanOligoPlate'} = 1;
		$self -> {'DnaPlate'} = $barcode;
		my $desc = $rinfo{'dye_name'}.' '.$rinfo{'primer_direction'}.' '.$rinfo{'primer_type'};
		return ($desc, $pses);
	    }
	    
	}
    
	return($result, $pses);
    }
    else {
	
	my $result = $self -> {'GetAvailOligoPlate'} -> xSql($barcode);

	if($result) {
	    my $subclones = $self -> {'GetSubPlIdsFromBarProcess'} -> xSql($self->{'DnaPlate'}, 'elution');
	    my $oligo_exists = LoadSql($dbh, qq/select count(pri_pri_id) from custom_primer_pse cp, pse_barcodes pb where direction = 'out' and
					   bs_barcode = '$barcode' and dna_id = ? and dl_id = ? and cp.pse_pse_id = pb.pse_pse_id/, 'Single');
	    foreach my $subclone (@{$subclones}) {
		my $count = $oligo_exists -> xSql($subclone->[0], $subclone->[1]);
		if($count != 1) {
		    #print "$subclone->[0], $subclone->[1]\n";
		    $self -> {'Error'} = "$pkg: GetAvailPrefinishOligoSequence -> Oligo plate does not match dna plate subclones.";
		    return (0);
		}
	    }
	    
	    $self -> {'DnaPlate'} = '';
	    $self -> {'ScanOligoPlate'} = 0;
	    return(' oligo plate', undef);
	}
	else {
	    $self -> {'Error'} = "$pkg: GetAvailPrefinishOligoSequence() -> Oligo plate not checked in.";
	    return 0;
	}
    }
   

}


sub GetAvailOligoInprogress {

    my ($self, $barcode, $ps_id) = @_;
    
    my $result = $self -> {'GetAvailOligoPlate'} -> xSql($barcode);

    if($result) {

        return ("96 well oligo plate", $result);
    }

    $self->{'Error'} = "$pkg: Could not find oligo plate in correct state.";
    return 0;
}

#sub GetAvailSequenceOutInprogressPf {

#    my ($self, $barcode, $ps_id) = @_;

#    my $status = 'inprogress';
#    my $direction = 'out';
#    my ($result, $pses) = $self->GetAvailSeqDnaPf($barcode, $ps_id, $status, $direction, 'Directed Sequencing');

#    return ($result, $pses);

#}

sub GetAvailSequenceOutInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my $status = 'inprogress';
    my $direction = 'out';
    my ($result, $pses) = $self->GetAvailSeqDna($barcode, $ps_id, $status, $direction, 'Automated Production');

    return ($result, $pses);

} #GetAvailSequenceOutInprogress



sub GetAvailSequenceToRearray {

    my ($self, $barcode, $ps_id) = @_;

    my $status = 'inprogress';
    my $direction = 'in';
    my ($result, $pses) = $self->GetAvailSeqDna($barcode, $ps_id, $status, $direction, 'Automated Production');

    return ($result, $pses);

} #GetAvailSequenceToRearray

###############################
# Get available sequenced dna #
###############################
#sub GetAvailSeqDnaPf {

#    my ($self, $barcode, $ps_id, $status, $direction, $purpose) = @_;

#    my $lol = $self -> {'GetAvailSeqDnaPf'} ->xSql($status, $barcode, $direction, $ps_id, $purpose);
    
#    if(defined $lol->[0]) {
#	my $pses = [];
#	for my $i (0 .. $#{$lol}) {
#	    push(@{$pses}, $lol->[$i]);
#	}
	
#	my $desc=$self->{'GetBarcodeDesc'} ->xSql($barcode);
#	return ($desc, $pses);
#    }
    
#    $self->{'Error'} = "$pkg: GetAvailSeqDnaPf() -> Could not find barcode description information for barcode = $barcode, ps_id = $ps_id, status = $status.";
	
#    return 0;

#} 


###########################################
# Get available oligo checkin in progress #
###########################################
sub GetAvailOligoOutInprogress {

    my ($self, $barcode, $ps_id, $status, $direction, $purpose) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
						
    my $lol = $self -> {'GetAvailOligoOutInprogress'} ->xSql("out", $barcode, $ps_id);
    #pse.pse_id, dsp.pri_pri_id, dsp.dl_id, d.dna_id, bs_barcode, direction, dl.location_name
    if(defined $lol->[0][0]) {
	#my $lib = substr($lol->[0][0], 5, 5);
	my ($lib) = $lol->[0][0] =~ /^(.*)[A-H]\d\d$/;
	my $pses = [];
	my $pname = "";
	foreach my $line (@$lol) {
	  if(! grep(/^$line->[1]$/, @$pses)) {
	    push @{$pses}, $line->[1];
	    $pname = $line->[11];
	  }
	}
	return ($pname, $pses);
    }
	
    $self->{'Error'} = "$pkg: GetAvailOligoOutInprogress() -> Could not find barcode description information for barcode = $barcode, ps_id = $ps_id, direction = $direction.";
    
	
    return 0;

} #GetAvailGenome
sub AliquotOptions {
    
    my ($self) = @_;

    my @ret_array=();
    for my $i (1..12) {
	push @ret_array, "Column $i";
    }

    return(\@ret_array);
} # PCRFragmentOptions

 
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

    my $desc = $self -> CheckIfUsed($barcode, 'out');
    return ($self->GetCoreError) if(!$desc);
    return $desc;

} #CheckIfUsedAsOutput



############################################################################################
#                                                                                          #
#                         Confirm Subrotine Processes                                      #
#                                                                                          #
############################################################################################

sub VerifyGrowths {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my @no_grows;
    my $pse_ids = [];
    my $data_options = $options->{'Data'};
    if(defined $data_options) {
	
	foreach my $pso_id (keys %{$data_options}) {
	    my $info = $data_options -> {$pso_id};
	    if(defined $info) {
		my $sql = "select OUTPUT_DESCRIPTION from process_step_outputs where pso_id = '$pso_id'";
		my $desc = Query($self->{'dbh'}, $sql);
		if($desc eq 'No Grow Selection') {
		    if((defined $$info) && ($$info ne '') && ($$info ne 'select no grows')) { 
			@no_grows = split(/\t/, $$info);
		    }
		}
	    }
	}
    }

    my $lol = $self->{'GetBarcodeSubPlWellPse'} -> xSql('out', $bars_in->[0], 'inprogress', 'pick targeted subclones');
    foreach my $pre_pse_id (@{$pre_pse_ids}) {
	
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	return 0 if($result == 0);
	
    }
	
    my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'inprogress', '', $emp_id, undef, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$new_pse_id);

    my $fail_pse_id;
    if($#no_grows != -1) {
	
	$fail_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'abandoned', 'terminated', $emp_id, undef, $pre_pse_ids->[0]);
	return ($self->GetCoreError) if(!$fail_pse_id);
	
    }

    foreach my $row (@{$lol}) {
	
	my @inlist = grep(/^$row->[2]$/, @no_grows);
	my $result;
	if($#inlist == -1) {

	    #$result = $self -> InsertSubclonesPses($new_pse_id, $row->[0], $row->[1]);
	    $result = $self -> InsertDNAPSE($row->[0], $new_pse_id, $row->[1]);
	}
	else {
	    $result = $self -> InsertDNAPSE($row->[0], $new_pse_id, $row->[1]);
	    $result = $self -> InsertDNAPSE($row->[0], $fail_pse_id, $row->[1]);
#	    $result = $self -> InsertSubclonesPses($fail_pse_id, $row->[0], $row->[1]);
#	    $result = $self -> InsertSubclonesPses($new_pse_id, $row->[0], $row->[1]);
	}
	return 0 if($result == 0);
    }
    
    push(@{$pse_ids}, $new_pse_id);

    return $pse_ids;

}

sub ArchiveTargetedSubclones {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];

    my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'completed', 'successful', $emp_id, undef, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$new_pse_id);


    
    my $lol = $self->{'GetBarcodeSubPlWellPse'} -> xSql('in', $bars_in->[0], 'inprogress', 'verify growths');
    
    foreach my $row (@{$lol}) {
	
	#my $result = $self -> InsertSubclonesPses($new_pse_id, $row->[0], $row->[1]);
	my $result = $self -> InsertDNAPSE($row->[0], $new_pse_id, $row->[1]);
	return 0 if($result == 0);
    }

    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;
   
} #ArchiveTargetedSubclones


#########################################
# Process Claim Archive Barcode Request #
#########################################
sub ClaimPfPlate {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];

    foreach my $pre_pse_id (@{$pre_pse_ids}) {
	
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	return 0 if($result == 0);
    }

    my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'inprogress', '', $emp_id, undef, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$new_pse_id);


    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;
} #ClaimPfPlate


sub PrepProcessing {
 
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];

    my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'inprogress', '', $emp_id, undef, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$new_pse_id);
    
    foreach my $pre_pse_id (@{$pre_pse_ids}) {
	
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	return 0 if($result == 0);
	
	my $lol = $self->{'GetBarcodeSubPlWellPse'} -> xSql('in', $bars_in->[0], 'completed', 'verify growths');

	
	foreach my $row (@{$lol}) {
	    
#	    my $result = $self -> InsertSubclonesPses($new_pse_id, $row->[0], $row->[1]);
	    my $result = $self -> InsertDNAPSE($row->[0], $new_pse_id, $row->[1]);
	    return 0 if($result == 0);
	}
    }

    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;

}


sub SubcloneToSubcloneTransferPf {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my $pse_ids = [];
    

    foreach my $pre_pse_id (@{$pre_pse_ids}) {
	
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	return 0 if($result == 0);
    }

    my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'inprogress', '', $emp_id, undef, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$new_pse_id);
    

    my $lol = $self->{'GetBarcodeSubPlPse'} -> xSql($bars_in->[0], 'completed');

    foreach my $row (@{$lol}) {

#	my $result = $self -> InsertSubclonesPses($new_pse_id, $row->[0], $row->[1]);
	my $result = $self -> InsertDNAPSE($row->[0], $new_pse_id, $row->[1]);
	return 0 if($result == 0);
    }
    
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;


}#SubcloneToSubcloneTransfer


sub ElutionTransfer {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my $pse_ids = [];
    

    foreach my $pre_pse_id (@{$pre_pse_ids}) {
	
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	return 0 if($result == 0);
    }

    my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'inprogress', '', $emp_id, undef, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$new_pse_id);
    

    my $lol = $self->{'GetElutionDnaDlPse'} -> xSql($bars_in->[0]);

    if(!defined $lol->[0][0]) {

	$self->{'Error'} = "$pkg: ElutionTransfer() -> No subclones to transfer.";
	return 0;
      
    }
	
    foreach my $row (@{$lol}) {
	
	my $result = $self -> InsertDNAPSE($row->[0], $new_pse_id, $row->[1]);
	return 0 if($result == 0);
    }
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;


}#ElutionTransfer

    
    sub RearrayElutionPlates {
        
        my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;
        
        my $pse_ids = [];
        my $plate_type = '384';
        my $update_status = 'completed';
        my $update_result = 'successful';
        my $status = 'inprogress';
        
        my @sectors =  qw(a1 a2 b1 b2);
        
        for my $i (0 .. $#{$bars_in}) {    
            if(!($bars_in->[$i] =~ /^empty/)) {
                
                my $sec_id =  $self-> Process('GetSectorId', $sectors[$i]);
                return ($self->GetCoreError) if(!$sec_id);
                
                my $pre_pse_ids = $self  -> Process('GetPrePseForBarcode', $bars_in->[$i], 'out', $status, $ps_id);
                return 0 if(!$pre_pse_ids);
                
                my $pre_pse_id = $pre_pse_ids->[0];
                
                my ($new_pse_id) = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
           
                my @dps = GSC::DNAPSE->get(pse_id => $pre_pse_id);
                
                foreach my $dp (@dps) {
                    my ($well_384) = &ConvertWell::To384(GSC::DNALocation->get(dl_id => $dp->dl_id)->location_name, $sectors[$i]);
                    
                    unless(GSC::DNAPSE->create(pse_id => $new_pse_id,
                                               dl_id  => GSC::DNALocation->get(location_name => $well_384,
                                                                               sec_id        => GSC::Sector->get(sector_name =>  $sectors[$i]),
                                                                               location_type => '384 well plate'),
                                               dna_id => $dp->dna_id)) {
                        $self->{'Error'} = "$pkg: RearrayElutionPlates -> failed to create dna_pse";
                        return;
                    }
                }                
                
                push(@{$pse_ids}, $new_pse_id);
                
            }
        }
        
        return $pse_ids;
    } #RearraySequencePlates

sub RearrayPlatesWithQuadCheck {
        
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = [];
    my $plate_type = '384';
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
        
    my @sectors =  qw(a1 a2 b1 b2);
    
    for my $i (0 .. $#{$bars_in}) {    
        if(!($bars_in->[$i] =~ /^empty/)) {
                
            my $sec_id =  $self-> Process('GetSectorId', $sectors[$i]);
            return ($self->GetCoreError) if(!$sec_id);

            my $secs = $self -> {'CheckBarcodeQuadrant'}->xSql($bars_in->[$i]);
            if($secs->[0]) {
                if($#{$secs} > 1) {
                    $self->{'Error'}="$pkg: multiple sectors found for dna plate.";
                    return;
                }
                
                unless($sectors[$i] eq $secs->[0][0]) {
                    $self->{'Error'}="$pkg: the rearray sector does not match a 384 well primer plate sector, $sectors[$i].";
                    return;
                }
            
            }
            else {
                $self->{'Error'}="$pkg: no custom primer plate sectors found for the dna plate.";
                return;
            }            
            my $pre_pse_ids = $self  -> Process('GetPrePseForBarcode', $bars_in->[$i], 'in', $status, $ps_id);
            unless($pre_pse_ids) {
                $pre_pse_ids = $self  -> Process('GetPrePseForBarcode', $bars_in->[$i], 'out', $status, $ps_id);
            }

            return 0 if(!$pre_pse_ids);
            
            my $pre_pse_id = $pre_pse_ids->[0];
            
            my ($new_pse_id) = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
            
            my @dps = GSC::Barcode->get_dna_pse(barcode=>$bars_in->[$i]);
#            my @dps = GSC::DNAPSE->get(pse_id => $pre_pse_id);
            
            foreach my $dp (@dps) {
                my ($well_384) = &ConvertWell::To384(GSC::DNALocation->get(dl_id => $dp->dl_id)->location_name, $sectors[$i]);
                
                unless(GSC::DNAPSE->create(pse_id => $new_pse_id,
                                           dl_id  => GSC::DNALocation->get(location_name => $well_384,
                                                                           sec_id        => GSC::Sector->get(sector_name =>  $sectors[$i]),
                                                                           location_type => '384 well plate'),
                                           dna_id => $dp->dna_id)) {
                    $self->{'Error'} = "$pkg: RearrayElutionPlates -> failed to create dna_pse";
                    return;
                }
            }                
            
            push(@{$pse_ids}, $new_pse_id);
            
        }
    }
    
    return $pse_ids;
} #RearraySequencePlates
sub RearrayPlatesWithNoQuadCheck {
        
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = [];
    my $plate_type = '384';
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
        
    my @sectors =  qw(a1 a2 b1 b2);
    
    for my $i (0 .. $#{$bars_in}) {    
        if(!($bars_in->[$i] =~ /^empty/)) {
                
            my $sec_id =  $self-> Process('GetSectorId', $sectors[$i]);
            return ($self->GetCoreError) if(!$sec_id);


            my $pre_pse_ids = $self  -> Process('GetPrePseForBarcode', $bars_in->[$i], 'in', $status, $ps_id);
            unless($pre_pse_ids) {
                $pre_pse_ids = $self  -> Process('GetPrePseForBarcode', $bars_in->[$i], 'out', $status, $ps_id);
            }

            return 0 if(!$pre_pse_ids);
            
            my $pre_pse_id = $pre_pse_ids->[0];
            
            my ($new_pse_id) = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
            
            my @dps = GSC::Barcode->get_dna_pse(barcode=>$bars_in->[$i]);
#            my @dps = GSC::DNAPSE->get(pse_id => $pre_pse_id);
            
            foreach my $dp (@dps) {
                my ($well_384) = &ConvertWell::To384(GSC::DNALocation->get(dl_id => $dp->dl_id)->location_name, $sectors[$i]);
                
                unless(GSC::DNAPSE->create(pse_id => $new_pse_id,
                                           dl_id  => GSC::DNALocation->get(location_name => $well_384,
                                                                           sec_id        => GSC::Sector->get(sector_name =>  $sectors[$i]),
                                                                           location_type => '384 well plate'),
                                           dna_id => $dp->dna_id)) {
                    $self->{'Error'} = "$pkg: RearrayElutionPlates -> failed to create dna_pse";
                    return;
                }
            }                
            
            push(@{$pse_ids}, $new_pse_id);
            
        }
    }
    
    return $pse_ids;
} #RearraySequencePlates

sub RearrayPrimerPlates {
    
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = [];
    my $plate_type = '384';
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
    
    my @sectors =  qw(a1 a2 b1 b2);
    
    for my $i (0 .. $#{$bars_in}) {    
        if(!($bars_in->[$i] =~ /^empty/)) {
            
            my $pre_pse_ids = $self -> Process('GetPrePseForBarcode', $bars_in->[$i], 'in', $status, $ps_id);
            return 0 if(!$pre_pse_ids);
            
            my $pre_pse_id =  $pre_pse_ids->[0]; 
            
            my ($new_pse_id) = $self-> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
            
            my @bar_pse = GSC::PSEBarcode->get(barcode => $bars_in->[$i],
                                               direction => 'out');
            
            my @cpp = GSC::CustomPrimerPSE->get(pse_id =>\@bar_pse);
            
            foreach my $cpp (@cpp) {
                my ($well_384) = &ConvertWell::To384(GSC::DNALocation->get(dl_id => $cpp->dl_id)->location_name, $sectors[$i]);
                
                unless(GSC::CustomPrimerPSE->create(pse_id => $new_pse_id,
                                                    dl_id  => GSC::DNALocation->get(location_name => $well_384,
                                                                                    sec_id        => GSC::Sector->get(sector_name =>  $sectors[$i]),
                                                                                    location_type => '384 well plate'),
                                                    pri_id => $cpp->pri_id,
                                                    dna_id => $cpp->dna_id),
                       
                       ) {
                    
                    $self->{'Error'} = "$pkg: RearrayPrimerPlates() -> CustomPrimerPSE failed to create.";
                }
                
            }
            
            
            push(@{$pse_ids}, $new_pse_id);
            
        }
    }
    return $pse_ids;
} #RearraySequencePlates


sub SeqDnaToSeqDnaTransfer {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my $pse_ids = [];
    

    foreach my $pre_pse_id (@{$pre_pse_ids}) {
	
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	return 0 if($result == 0);
    }

    my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'inprogress', '', $emp_id, undef, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$new_pse_id);
    

    my $lol = $self->{'GetSeqDnaPlIdInBarcode'} -> xSql($bars_in->[0]);
    foreach my $row (@{$lol}) {

#	my $result = $self -> InsertSeqDnaPses($new_pse_id, $row->[0], $row->[1]);
	my $result = $self -> InsertDNAPSE($row->[0], $new_pse_id, $row->[1]);
	return 0 if($result == 0);
    }
    
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;


}#SeqDnaToSeqDnaTransfer

sub SeqDnaToSeqDnaTransferWithNoDNAPSE {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my $pse_ids = [];
    

    foreach my $pre_pse_id (@{$pre_pse_ids}) {
	
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	return 0 if($result == 0);
    }

    my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'inprogress', '', $emp_id, undef, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$new_pse_id);
    
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;


}#SeqDnaToSeqDnaTransfer

sub SeqDnaToSeqDnaTransfer384 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my $pse_ids = [];
    

    foreach my $pre_pse_id (@{$pre_pse_ids}) {
	
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	return 0 if($result == 0);
        
        my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'inprogress', '', $emp_id, undef, $pre_pse_id);
        return ($self->GetCoreError) if(!$new_pse_id);
        
        my $sector = GSC::Sector->get(sec_id => [GSC::DNALocation->get(dl_id => [GSC::DNAPSE->get(pse_id => $pre_pse_id)])]);
        return 0 unless($sector);

        my @dna_pse = GSC::DNAPSE->get(pse_id => [GSC::PSEBarcode->get(barcode => $bars_in->[0],
                                                                       direction => 'out')],
                                       dl_id => [GSC::DNALocation->get(location_type => '384 well plate',
                                                                       sec_id => $sector->sec_id)]);
        foreach my $dna_pse (@dna_pse) {

          GSC::DNAPSE->create(dna_id => $dna_pse->dna_id,
                              pse_id => $new_pse_id,
                              dl_id => $dna_pse->dl_id) or return;
        }           
        #my $lol = $self->{'GetSeqDnaPlIdInBarcode'} -> xSql($bars_in->[0]);
#        foreach my $row (@{$lol}) {
            
#	my $result = $self -> InsertSeqDnaPses($new_pse_id, $row->[0], $row->[1]);
#            my $result = $self -> InsertDNAPSE($row->[0], $new_pse_id, $row->[1]);
#            return 0 if($result == 0);
#        }
        
        push(@{$pse_ids}, $new_pse_id);
     }
   
    return $pse_ids;


}#SeqDnaToSeqDnaTransfer
sub SeqDnaToSeqDnaTransfer384WithNoDNAPSE {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my $pse_ids = [];
    

    foreach my $pre_pse_id (@{$pre_pse_ids}) {
	
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	return 0 if($result == 0);
        
        my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'inprogress', '', $emp_id, undef, $pre_pse_id);
        return ($self->GetCoreError) if(!$new_pse_id);
        
        my $sector = GSC::Sector->get(sec_id => [GSC::DNALocation->get(dl_id => [GSC::DNAPSE->get(pse_id => $pre_pse_id)])]);
        return 0 unless($sector);
        
        push(@{$pse_ids}, $new_pse_id);
     }
   
    return $pse_ids;


}#SeqDnaToSeqDnaTransfer



###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub SequencePrefinish {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
    my $dye_chem_id = $options->{'GetPfDyeChemId'};
    my $primer_id = $options->{'GetPfPrimerId'};
    my $enz_id = $options->{'GetPfEnzId'};
    my $reagent = $options->{'GetReagentName'};

    return 0 if(! defined $dye_chem_id);
    return 0 if(! defined $primer_id);
    return 0 if(! defined $enz_id);
    return 0 if(! defined $reagent);
 
    #my $pt_id = $self -> Process('GetPlateTypeId', 96);
    my $pt_id = "96 well plate";
    #return 0 if($pt_id == 0);
    return 0 if(! $pt_id);
    
    my $result = $self -> ComparePrimerReagentToAvailVector($reagent, $bars_in->[0]);
    return 0 if(!$result);
    
    my $plate_pse_ids = $self->{'GetBarocdeCreatePse'} -> xSql($bars_in->[0]);
    return (0) if(!defined $plate_pse_ids);
    my $plate_pse_id = $plate_pse_ids->[0];
    
    my $pre_pse_ids = $self -> Process('GetPrePseForBarcode', $bars_in->[0], 'in', $status, $ps_id);
    return ($self->GetCoreError) if(!$pre_pse_ids);
    
    my $pre_pse_id = $pre_pse_ids->[0];
	    
    $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
    return 0 if($result == 0);
    
    my $sec_id = $self -> Process('GetSectorId', 'a1');
    return ($self->GetCoreError) if(!$sec_id);
    
    
    my $new_pse_id = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bars_out->[0]], $emp_id);
    return 0 if ($new_pse_id == 0);


    $result = $self -> CreateSequenceDna($bars_in->[0], $plate_pse_id, $dye_chem_id, $primer_id, $enz_id, $pt_id, $sec_id, $new_pse_id);
    return 0 if ($result == 0);
    
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;
} #SequencePrefinish


###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub SequencePrefinish384Universal {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
    my $dc_id = $options->{'GetPfDyeChemId'};
    my $pri_id = $options->{'GetPfPrimerId'};
    my $enz_id = $options->{'GetPfEnzId'};
    my $reagent = $options->{'GetReagentName'};

    return 0 if(! defined $dc_id);
    return 0 if(! defined $pri_id);
    return 0 if(! defined $enz_id);
    return 0 if(! defined $reagent);

    my $i = 0;

    my $dye_type_name = Query($self->{'dbh'}, qq/select DYETYP_DYE_NAME from dye_chemistries where dc_id = $dc_id/);
    my $dye_type_like;
    my %dcs;
    if(defined $dye_type_name) {
	my ($dye_type, $ver) = split(/\sV/, $dye_type_name);
	$dye_type_like = $dye_type.'%';
	%dcs = %{{ map +( $_->dc_id => $_ ), GSC::DyeChemistry->get(dye_name => { operator => 'like', value => "$dye_type_like" }) }};
    }
    else {
	$self->{'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find dye type name for dc_id = $dc_id.";
	return 0;
    }

    my $result = $self -> ComparePrimerReagentToAvailVector($reagent, $bars_in->[0]);
    return 0 if(!$result);
    
    foreach my  $pre_pse_id (@$pre_pse_ids) {
        
        my $dna_bar = $self->{'GetInputBarcodeWithPse'}->xSql($bars_in->[0], $pre_pse_id);
        
        my $new_pse_id = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [], $emp_id);
        return 0 if ($new_pse_id == 0);
        
        my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
        return 0 if($result == 0);
        
        my ($ds_barcode, %rinfo) = $self->GetDirSeqInfo($dna_bar);
        return 0 if(!$ds_barcode);
        
        my $asetup = $self -> {'GetAllSetup'} -> xSql($ds_barcode);
	my %dsinfo;
        foreach my $s (@$asetup) {
            push @{$dsinfo{$s->[0]}->{$s->[1]}->{$s->[2]}->{$s->[3]}->{$s->[5]}}, $s;
	}        

        my $sub_infos = $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($bars_in->[0], $pre_pse_id);
        
        foreach my $sub_info (@{$sub_infos}) {
            my $sub_id = $sub_info->[0];
            my $pl_id  = $sub_info->[2];
            
            my ($well_96, $sector) = &ConvertWell::To96(GSC::DNALocation->get(dl_id => $pl_id)->location_name);
            print "well = $well_96, sector = $sector\n";
            my $dl_id_96 = GSC::DNALocation->get(location_name => $well_96,
                                                 sec_id  => 1,
                                                 location_type => '96 well plate')->dl_id;
            
            
	    my $ds_id;
            foreach my $info (@{$dsinfo{$ds_barcode}->{$sub_id}->{$dl_id_96}->{$pri_id}->{$enz_id}}) {
	      if($dcs{$info->[4]}) {
	        $ds_id = $info->[6];
		last;
	      }
	    }
	    if(! $ds_id) {
                $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find direct seq id.";
                return 0;
            }            
#            my $ds_infos = $self -> {'PrefinishDsDcEnzPriIds'} -> xSql($ds_barcode, $sub_id, $dl_id_96, $pri_id, $dye_type_like, $enz_id);
            
#            if(! defined $ds_infos->[0][0]) {
#                $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find direct seq id.";
#                return 0;
#            }
#            my $ds_id = $ds_infos->[0][0];
            
            my $seq_id = $self->GetNextSeqdnaId;
            
            # insert subclone into table
            my $result = $self->InsertSequencedDnas($sub_id, $pri_id, $dc_id, $enz_id, $seq_id, $new_pse_id, $pl_id, $ds_id);
            return 0 if(!$result);
            
        }
        
        push(@{$pse_ids}, $new_pse_id);
        $i++;
    }


    
    return $pse_ids;
} #SequencePrefinish


###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub SequenceWithCustomPrimers {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
    my $reagent = $options->{'GetReagentName'};
    if(! defined $reagent) {
	$self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find reagent name.";
	return 0 ;
    }
    my $dc_id = Query($self->{'dbh'}, qq/select dc_dc_id from dye_chemistries_reagent_names where rn_reagent_name = '$reagent'/);

    if(! defined $dc_id) {
	$self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find dc_id.";
	return 0 ;
    }
    
    my $dye_type_name = Query($self->{'dbh'}, qq/select DYETYP_DYE_NAME from dye_chemistries where dc_id = $dc_id/);
    my $dye_type_like;
    if(defined $dye_type_name) {
	my ($dye_type, $ver) = split(/\sV/, $dye_type_name);
	$dye_type_like = $dye_type.'%';
    }
    else {
	$self->{'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find dye type name for dc_id = $dc_id.";
	return 0;
    }
    my $enz_id =  Query($self->{'dbh'}, qq/select enz_enz_id from enzymes_reagent_names where rn_reagent_name = '$reagent'/);
    if(! defined $enz_id) {
	$self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find enz_id.";
	return 0 ;
    }

#    my $result = $self -> ComparePrimerReagentToAvailVector($reagent, $bars_in->[0]);
#    return 0 if(!$result);

    
    my $oligo_pse = $self -> {'GetAvailOligoPlate'} -> xSql($bars_in->[1]);
    my $result = $self -> Process('UpdatePse', 'completed', 'successful', $oligo_pse);
    return 0 if($result == 0);

    my $pre_pse_id = $pre_pse_ids->[0];
    
    my $new_pse_id = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bars_out->[0]], $emp_id);
    return 0 if ($new_pse_id == 0);

    my ($ds_barcode, %rinfo) = $self->GetDirSeqInfo($bars_in->[0]);
    return 0 if(!$ds_barcode);

    $result = $self -> Process('InsertBarcodeEvent', $bars_in->[1], $new_pse_id, 'in');
    return ($self->GetCoreError) if(!$result);
    
    my $sub_infos = $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($bars_in->[0], $pre_pse_id);
    
    my $pri_id_sql = LoadSql($self->{'dbh'}, qq/select pri_pri_id from custom_primer_pse cp, pse_barcodes pb where direction = 'out' and
				 bs_barcode = ? and dna_id = ? and dl_id = ? and cp.pse_pse_id = pb.pse_pse_id/, 'Single');

    foreach my $sub_info (@{$sub_infos}) {
	my $sub_id = $sub_info->[0];
	my $pl_id  = $sub_info->[2];
	
	my $pri_id = $pri_id_sql -> xSql($bars_in->[1], $sub_id, $pl_id);

	my $ds_infos = $self -> {'PrefinishDsDcEnzPriIds'} -> xSql($ds_barcode, $sub_id, $pl_id, $pri_id, $dye_type_like, $enz_id);

	if(! defined $ds_infos->[0][0]) {
	    $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find direct seq id.";
	    return 0;
	}
	my $ds_id = $ds_infos->[0][0];
	
	my $seq_id = $self->GetNextSeqdnaId;
	
	# insert subclone into table
	my $result = $self->InsertSequencedDnas($sub_id, $pri_id, $dc_id, $enz_id, $seq_id, $new_pse_id, $pl_id, $ds_id);
	return 0 if(!$result);
	
#	$result = $self -> InsertSeqDnaPses($new_pse_id, $seq_id, $pl_id);
#	return 0 if ($result == 0);
	
#	$result = $self -> InsertDirSeqDna($seq_id, $ds_id);
#	return 0 if ($result == 0);
	
	
    }
    
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;
} #SequenceWithCustomPrimers


###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub SequenceWithCustomPrimers384 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
    my $reagent = $options->{'GetReagentName'};
    #my $reagent = '4:1 ver3.1 Premix';
    if(! defined $reagent) {
	$self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find reagent name.";
	return 0 ;
    }
    my $dc_id = Query($self->{'dbh'}, qq/select dc_dc_id from dye_chemistries_reagent_names where rn_reagent_name = '$reagent'/);

    if(! defined $dc_id) {
	$self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find dc_id.";
	return 0 ;
    }
    
    my $dye_type_name = Query($self->{'dbh'}, qq/select DYETYP_DYE_NAME from dye_chemistries where dc_id = $dc_id/);
    my $dye_type_like;
    if(defined $dye_type_name) {
	my ($dye_type, $ver) = split(/\sV/, $dye_type_name);
	$dye_type_like = $dye_type.'%';
    }
    else {
	$self->{'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find dye type name for dc_id = $dc_id.";
	return 0;
    }
    my $enz_id =  Query($self->{'dbh'}, qq/select enz_enz_id from enzymes_reagent_names where rn_reagent_name = '$reagent'/);
    if(! defined $enz_id) {
	$self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find enz_id.";
	return 0 ;
    }

    my $i = 0;

    
    my $oligo_pses = $self -> {'GetAvailPrimerPlate'} -> xSql($bars_in->[1]);
    foreach my $oligo_pse (@$oligo_pses) {
        my $result = $self -> Process('UpdatePse', 'completed', 'successful', $oligo_pse);
        return 0 if($result == 0);
    }


    foreach my  $pre_pse_id (@$pre_pse_ids) {
        
    
        my $dna_bar = $self->{'GetInputBarcodeWithPse'}->xSql($bars_in->[0], $pre_pse_id);
      
        my $new_pse_id = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [], $emp_id);
        return 0 if ($new_pse_id == 0);
        
        my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
        return 0 if($result == 0);
        
        my ($ds_barcode, %rinfo) = $self->GetDirSeqInfo($dna_bar);
        return 0 if(!$ds_barcode);
        
        my $result = $self -> Process('InsertBarcodeEvent',$bars_in->[1], $new_pse_id, 'in');
        return ($self->GetCoreError) if(!$result);
        
        my $sub_infos = $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($bars_in->[0], $pre_pse_id);
        
        my $pri_id_sql = LoadSql($self->{'dbh'}, qq/select pri_pri_id from custom_primer_pse cp, pse_barcodes pb where direction = 'out' and
				 bs_barcode = ? and dna_id = ? and dl_id = ? and cp.pse_pse_id = pb.pse_pse_id/, 'Single');
        
        foreach my $sub_info (@{$sub_infos}) {
            my $sub_id = $sub_info->[0];
            my $pl_id  = $sub_info->[2];
            
            my ($well_96, $sector) = &ConvertWell::To96(GSC::DNALocation->get(dl_id => $pl_id)->location_name);
            print "well = $well_96, sector = $sector\n";
            my $dl_id_96 = GSC::DNALocation->get(location_name => $well_96,
                                                 sec_id  => 1,
                                                 location_type => '96 well plate')->dl_id;
            
            my $pri_id = $pri_id_sql -> xSql($bars_in->[1], $sub_id, $pl_id);
            
            my $ds_infos = $self -> {'PrefinishDsDcEnzPriIds'} -> xSql($ds_barcode, $sub_id, $dl_id_96, $pri_id, $dye_type_like, $enz_id);
            
            if(! defined $ds_infos->[0][0]) {
                $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find direct seq id.";
                return 0;
            }
            my $ds_id = $ds_infos->[0][0];
            
            my $seq_id = $self->GetNextSeqdnaId;
            
            # insert subclone into table
            my $result = $self->InsertSequencedDnas($sub_id, $pri_id, $dc_id, $enz_id, $seq_id, $new_pse_id, $pl_id, $ds_id);
            return 0 if(!$result);
            
#	$result = $self -> InsertSeqDnaPses($new_pse_id, $seq_id, $pl_id);
#	return 0 if ($result == 0);
            
#	$result = $self -> InsertDirSeqDna($seq_id, $ds_id);
#	return 0 if ($result == 0);
            
            
        }
        
        push(@{$pse_ids}, $new_pse_id);
        $i++;
    }
    foreach my $oligo_pse (@$oligo_pses) {
    }

    return $pse_ids;
} #SequenceWithCustomPrimers

sub SequenceWithCustomPrimers384_scheduled {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
    my $reagent = $options->{'GetReagentName'};
    #my $reagent = '4:1 ver3.1 Premix';
    if(! defined $reagent) {
	$self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find reagent name.";
	return 0 ;
    }
    my $dc_id = Query($self->{'dbh'}, qq/select dc_dc_id from dye_chemistries_reagent_names where rn_reagent_name = '$reagent'/);

    if(! defined $dc_id) {
	$self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find dc_id.";
	return 0 ;
    }
    
    my $dye_type_name = Query($self->{'dbh'}, qq/select DYETYP_DYE_NAME from dye_chemistries where dc_id = $dc_id/);
    my $dye_type_like;
    my %dcs;
    if(defined $dye_type_name) {
	my ($dye_type, $ver) = split(/\sV/, $dye_type_name);
	$dye_type_like = $dye_type.'%';
	%dcs = %{{ map +( $_->dc_id => $_ ), GSC::DyeChemistry->get(dye_name => { operator => 'like', value => "$dye_type_like" }) }};
    }
    else {
	$self->{'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find dye type name for dc_id = $dc_id.";
	return 0;
    }
    my $enz_id =  Query($self->{'dbh'}, qq/select enz_enz_id from enzymes_reagent_names where rn_reagent_name = '$reagent'/);
    if(! defined $enz_id) {
	$self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find enz_id.";
	return 0 ;
    }

    my $i = 0;

    
    my $oligo_pses = $self -> {'GetAvailPrimerPlate'} -> xSql($bars_in->[1]);
    foreach my $oligo_pse (@$oligo_pses) {
        my $result = $self -> Process('UpdatePse', 'completed', 'successful', $oligo_pse);
        return 0 if($result == 0);
    }

    my @pbs = GSC::PSEBarcode->get(barcode => $bars_in->[1]);
    my %cpps = %{{ map +( $_->dl_id => $_ ), GSC::CustomPrimerPSE->get(pse_id => \@pbs) }};
    my @ibs = GSC::PSEBarcode->get(pse_id => $pre_pse_ids);
    my %ipbs;
    foreach my $ib (@ibs) {
      $ipbs{$ib->pse_id}->{$ib->direction} = $ib;
    }
    foreach my  $pre_pse_id (@$pre_pse_ids) {
	if($ipbs{$pre_pse_id}->{out}->barcode ne $bars_in->[0]) {
	  $self->error_message("Cannot find the dna barcode for pse_id $pre_pse_id!\n");
	  return;
	}
        my $dna_bar = $ipbs{$pre_pse_id}->{in}->barcode;
        my $new_pse_id = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [], $emp_id);
        return 0 if ($new_pse_id == 0);
        
        my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
        return 0 if($result == 0);
        
        my ($ds_barcode, %rinfo) = $self->GetDirSeqInfo($dna_bar);
        return 0 if(!$ds_barcode);
        
        my $asetup = $self -> {'GetAllSetup'} -> xSql($ds_barcode);
	my %dsinfo;
        foreach my $s (@$asetup) {
	  push @{$dsinfo{$s->[0]}->{$s->[1]}->{$s->[2]}->{$s->[3]}->{$s->[5]}}, $s;
	}        
        my $result = $self -> Process('InsertBarcodeEvent',$bars_in->[1], $new_pse_id, 'in');
        return ($self->GetCoreError) if(!$result);
        
        my $sub_infos = $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($bars_in->[0], $pre_pse_id);
        #LSF: We should get the whole plate instead of individual.
        my $pri_id_sql = LoadSql($self->{'dbh'}, qq/select pri_pri_id from custom_primer_pse cp, pse_barcodes pb where direction = 'out' and
				 bs_barcode = ? and dna_id = ? and dl_id = ? and cp.pse_pse_id = pb.pse_pse_id/, 'Single');
        
        foreach my $sub_info (@{$sub_infos}) {
            my $sub_id = $sub_info->[0];
            my $pl_id  = $sub_info->[2];
            
            my ($well_96, $sector) = &ConvertWell::To96(GSC::DNALocation->get(dl_id => $pl_id)->location_name);
            print "well = $well_96, sector = $sector\n";
            my $dl_id_96 = GSC::DNALocation->get(location_name => $well_96,
                                                 sec_id  => 1,
                                                 location_type => '96 well plate')->dl_id;
            
	    my $cpp = $cpps{$pl_id};
            #my $pri_id = $pri_id_sql -> xSql($bars_in->[1], $sub_id, $pl_id);
            my $pri_id = $cpp->dna_id == $sub_id ? $cpp->pri_id : 0;
	    my $ds_id;
            foreach my $info (@{$dsinfo{$ds_barcode}->{$sub_id}->{$dl_id_96}->{$pri_id}->{$enz_id}}) {
	      if($dcs{$info->[4]}) {
	        $ds_id = $info->[6];
		last;
	      }
	    }
	    if(! $ds_id) {
                $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find direct seq id.";
                return 0;
            }            
            #my $seq_id = $self->GetNextSeqdnaId;
            
            # insert subclone into table
            #my $result = $self->InsertSequencedDnas($sub_id, $pri_id, $dc_id, $enz_id, $seq_id, $new_pse_id, $pl_id, $ds_id);
            #return 0 if(!$result);            
        }
	#LSF: Changed the PSEs to scheduled status.
	my $np = GSC::PSE->get(pse_id => $new_pse_id);
	$np->pse_status('scheduled');
        
        push(@{$pse_ids}, $new_pse_id);
        $i++;
    }
    foreach my $oligo_pse (@$oligo_pses) {
    }

    return $pse_ids;
} #SequenceWithCustomPrimers

=head1 run_dna_creation

Will be called by the script to complete the sequence dna create with pse_id as input.

=cut

sub run_dna_creation {
  my($self, $pse_id) = @_;
  my $pse = GSC::PSE->get(pse_id => $pse_id);
  if($pse->pse_status ne 'scheduled') {
    $self->error_message("PSE ID [$pse_id] is not in scheduled pse status [" . $pse->pse_status . "]\n");
    return;
  }
  #LSF: Get all the barcode.
  my @pbs = GSC::PSEBarcode->get(pse_id => $pse_id);
  if(! @pbs) {
    die "Do not have any in barcode link to the $pse_id!\n";
  }
  #LSF: Rearray plate start with "22".
  my($re) = grep { $_->barcode =~ /^22/ } @pbs;
  my $barcode = $re->barcode;
  my $prior_pse_id = $pse->prior_pse_id;
  if(! $pse->prior_pse_id) {
    my $tpp_pse = GSC::TppPSE->get(pse_id => $pse_id, barcode => $barcode);
    if(! $tpp_pse) {
      die "Cannot find the prior pse id for pse_id $pse_id!\n";
    } 
    $prior_pse_id = $tpp_pse->prior_pse_id;
  }

  #LSF: Find all the information needed to create the sequence dna.
  #LSF: Get the premix.
  my @rups = GSC::ReagentUsedPSE->get(pse_id => $pse_id);
  my @ris = GSC::ReagentInformation->get(barcode => [ map { $_->bs_barcode } @rups]);
  my $reagent = $ris[0]->reagent_name;
    #my $reagent = '4:1 ver3.1 Premix';
  if(! defined $reagent) {
    $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find reagent name.";
    return 0 ;
  }
  my $dc_id = Query($self->{'dbh'}, qq/select dc_dc_id from dye_chemistries_reagent_names where rn_reagent_name = '$reagent'/);

  if(! defined $dc_id) {
    $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find dc_id.";
    return 0 ;
  }
    
  my $dye_type_name = Query($self->{'dbh'}, qq/select DYETYP_DYE_NAME from dye_chemistries where dc_id = $dc_id/);
  my $dye_type_like;
  my %dcs;
  if(defined $dye_type_name) {
    my ($dye_type, $ver) = split(/\sV/, $dye_type_name);
    $dye_type_like = $dye_type.'%';
    %dcs = %{{ map +( $_->dc_id => $_ ), GSC::DyeChemistry->get(dye_name => { operator => 'like', value => "$dye_type_like" }) }};
  }
  else {
    $self->{'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find dye type name for dc_id = $dc_id.";
    return 0;
  }
  my $enz_id =  Query($self->{'dbh'}, qq/select enz_enz_id from enzymes_reagent_names where rn_reagent_name = '$reagent'/);
  if(! defined $enz_id) {
    $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find enz_id.";
    return 0 ;
  }
  #LSF: Get the custom primer pse
  my %cpps = %{{ map +( $_->dl_id => $_ ), GSC::CustomPrimerPSE->get(pse_id => [GSC::PSEBarcode->get(barcode => \@pbs)] ) }};
  
  my @ibs = GSC::PSEBarcode->get(pse_id => $prior_pse_id);
  my %ipbs;
  foreach my $ib (@ibs) {
    $ipbs{$ib->pse_id}->{$ib->direction} = $ib;
  }
    
  unless($ipbs{$prior_pse_id}->{out}->barcode eq $pbs[0]->barcode || $ipbs{$prior_pse_id}->{out}->barcode eq $pbs[1]->barcode) {
    $self->error_message("Cannot find the dna barcode for pse_id $prior_pse_id!\n");
    return;
  }
  my $dna_bar = $ipbs{$prior_pse_id}->{in}->barcode;
        
        
  my ($ds_barcode, %rinfo) = $self->GetDirSeqInfo($dna_bar);
  return 0 if(!$ds_barcode);
        
  my $asetup = $self -> {'GetAllSetup'} -> xSql($ds_barcode);
  my %dsinfo;
  foreach my $s (@$asetup) {
    push @{$dsinfo{$s->[0]}->{$s->[1]}->{$s->[2]}->{$s->[3]}->{$s->[5]}}, $s;
  }        
        
  my $sub_infos = $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($barcode, $prior_pse_id);
        
  foreach my $sub_info (@{$sub_infos}) {
    my $sub_id = $sub_info->[0];
    my $pl_id  = $sub_info->[2];
            
    my ($well_96, $sector) = &ConvertWell::To96(GSC::DNALocation->get(dl_id => $pl_id)->location_name);
    #print "well = $well_96, sector = $sector\n";
    my $dl_id_96 = GSC::DNALocation->get(location_name => $well_96,
                                         sec_id  => 1,
                                         location_type => '96 well plate')->dl_id;

    my $cpp = $cpps{$pl_id};
    #my $pri_id = $pri_id_sql -> xSql($bars_in->[1], $sub_id, $pl_id);
    my $pri_id = $cpp->dna_id == $sub_id ? $cpp->pri_id : 0;
    my $ds_id;
    foreach my $info (@{$dsinfo{$ds_barcode}->{$sub_id}->{$dl_id_96}->{$pri_id}->{$enz_id}}) {
      if($dcs{$info->[4]}) {
	$ds_id = $info->[6];
	last;
      }
    }
    if(! $ds_id) {
        $self -> {'Error'} = "$pkg: SequenceWithCustomPrimers() -> Could not find direct seq id.";
        return 0;
    }            
    my $seq_id = $self->GetNextSeqdnaId;

    # insert subclone into table
    my $result = $self->InsertSequencedDnas($sub_id, $pri_id, $dc_id, $enz_id, $seq_id, $pse_id, $pl_id, $ds_id);
    return 0 if(!$result);            
  }
  return 1;
}

sub AddControlDna {
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
    my $dbh = $self->{'dbh'};

    my ($ds_barcode, %rinfo) = $self->GetDirSeqInfo($bars_in->[0]);
    return 0 if(!$ds_barcode);
    
    my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_ids->[0]);
    return 0 if($result == 0);

    my $new_pse = $self -> BarcodeProcessEvent($ps_id, undef, [$bars_in->[0]], 'inprogress', '', $emp_id, undef, $pre_pse_ids->[0]);
    return 0 if ($new_pse == 0);
    
    
    my $pri_id;
    my $sub_id;
    my $trace_name = 'cntrl_to_be_named';
    my $enz_id = $rinfo{'enz_id'};
    my $dc_id = $rinfo{'dc_id'};
    my $project = 'PREFIN_CTRLS';

    if($rinfo{'primer_direction'} eq 'forward') {

	$sub_id = $self->GetSubIdFromSubclone('odz22d11');
	$pri_id = $self->GetPriIdFromPrimer('-40UP');
    }
    else {
	$sub_id = $self->GetSubIdFromSubclone('jqp76b09');
	$pri_id = $self->GetPriIdFromPrimer('-40RP');
    }
    
    return 0 if(!$sub_id);
    return 0 if(!$pri_id);

    my $ds_id = $self->GetNextDsId;
    return 0 if(!$ds_id);

    $result = $self->InsertDirectSeq($enz_id, $pri_id, $dc_id, $sub_id, $project, $ds_id, $trace_name);
    return 0 if(!$result);


    my $sec_id = $self -> Process('GetSectorId', 'a1');
    return ($self->GetCoreError) if(!$sec_id);

    #my $pt_id = $self -> Process('GetPlateTypeId', 96);
    my $pt_id = "96 well plate";
    #return 0 if($pt_id == 0);
    return 0 if(! $pt_id);

    my $pl_id = $self -> GetPlId('h12', $sec_id, $pt_id);

	
    my $seq_id = $self->GetNextSeqdnaId;
    
    # insert subclone into table
    $result = $self->InsertSequencedDnas($sub_id, $pri_id, $dc_id, $enz_id, $seq_id, $new_pse, $pl_id, $ds_id);
    return 0 if(!$result);
    
#    $result = $self -> InsertSeqDnaPses($new_pse, $seq_id, $pl_id);
#   return 0 if ($result == 0);
	
    
    $result = $self->InsertDirectSeqPses($new_pse, $ds_id);
    return 0 if(!$result);
    
#    $result = $self -> InsertDirSeqDna($seq_id, $ds_id);
#    return 0 if ($result == 0);
    
    return ([$new_pse]);
 
} #AddControlDna


sub AddControlDna384 {
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
    my $dbh = $self->{'dbh'};

    my @pses;
    my %wells= ('a1' => 'o23',
                'a2' => 'o24',
                'b1' => 'p23',
                'b2' => 'p24');
    my $i=0;
    foreach my  $pre_pse_id (@$pre_pse_ids) {
    
        my $dna_bar = $self->{'GetInputBarcodeWithPse2'}->xSql($bars_in->[0], $pre_pse_id);



        my ($ds_barcode, %rinfo) = $self->GetDirSeqInfo($bars_in->[0]);
        return 0 if(!$ds_barcode);
        
        my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
        return 0 if($result == 0);
        
        my $new_pse = $self -> BarcodeProcessEvent($ps_id, undef, [$bars_in->[0]], 'inprogress', '', $emp_id, undef, $pre_pse_id);
        return 0 if ($new_pse == 0);
        
        
        my $pri_id;
        my $sub_id;
        my $trace_name = 'cntrl_to_be_named';
        my $enz_id = $rinfo{'enz_id'};
        my $dc_id = $rinfo{'dc_id'};
        my $project = 'PREFIN_CTRLS';
        
        if($rinfo{'primer_direction'} eq 'forward') {
            
            $sub_id = $self->GetSubIdFromSubclone('odz22d11');
            $pri_id = $self->GetPriIdFromPrimer('-40UP');
        }
        else {
            $sub_id = $self->GetSubIdFromSubclone('jqp76b09');
            $pri_id = $self->GetPriIdFromPrimer('-40RP');
        }
    
        return 0 if(!$sub_id);
        return 0 if(!$pri_id);
        
        my $ds_id = $self->GetNextDsId;
        return 0 if(!$ds_id);
        
        my $result = $self->InsertDirectSeq($enz_id, $pri_id, $dc_id, $sub_id, $project, $ds_id, $trace_name);
        return 0 if(!$result);
        
        my $sector = GSC::Sector->get(sec_id => [GSC::DNALocation->get(dl_id => [GSC::DNAPSE->get(pse_id => $pre_pse_id)])]);
        return 0 unless($sector);
            
#        my $sec_id = $self -> Process('GetSectorId', 'a1');
#        return ($self->GetCoreError) if(!$sec_id);
        
        #my $pt_id = $self -> Process('GetPlateTypeId', 96);
        my $pt_id = "96 well plate";
        #return 0 if($pt_id == 0);
        return 0 if(! $pt_id);
        
#        my $pl_id = $self -> GetPlId($wells[$i], $sec_id, $pt_id);
        my $dl_id = GSC::DNALocation->get(location_type => '384 well plate',
                                          location_name => $wells{$sector->sector_name},
                                          sec_id => $sector->sec_id);
                                          
        
	
        my $seq_id = $self->GetNextSeqdnaId;
        
        # insert subclone into table
        $result = $self->InsertSequencedDnas($sub_id, $pri_id, $dc_id, $enz_id, $seq_id, $new_pse, $dl_id, $ds_id);
        return 0 if(!$result);
        
#    $result = $self -> InsertSeqDnaPses($new_pse, $seq_id, $pl_id);
#   return 0 if ($result == 0);
	
    
        $result = $self->InsertDirectSeqPses($new_pse, $ds_id);
        return 0 if(!$result);
        
#    $result = $self -> InsertDirSeqDna($seq_id, $ds_id);
#    return 0 if ($result == 0);
        
        $i++;
        
push(@pses, $new_pse);
    }
    return (\@pses);
 
} #AddControlDna



############################################################################################
#                                                                                          #
#                    Post Confirm Subrotine Processes                                      #
#                                                                                          #
############################################################################################



############################################################################################
#                                                                                          #
#                      Information Retrevial Subrotines                                    #
#                                                                                          #
############################################################################################

#######################################
# Get the next seqdna_id sequence number #
#######################################
sub GetNextSeqdnaId {

    my ($self) = @_;
    my $seqdna_id = Query($self->{'dbh'}, "select seqdna_seq.nextval from dual");
    if($seqdna_id) {
	return $seqdna_id;
    }
    $self->{'Error'} = "$pkg: GetNextSeqdnaId() -> Could not get next seqdna_id.";

    return 0;
 
} #GetNextSeqdnaId


####################################################
# Get the plate id from the well, sec_id and pt_id #
####################################################
sub GetPlId {

    my ($self, $well, $sec_id, $pt_id) = @_;

    #my $pl_obj = GSC::DNALocation->get(well_name=>$well, sec_id=>$sec_id, pt_id=>$pt_id);
    my $pl_obj = GSC::DNALocation->get(location_name=>$well, sec_id=>$sec_id, location_type =>$pt_id);

    if(defined $pl_obj) {
	return $pl_obj->dl_id;
    }
    
    $self->{'Error'} = "$pkg: GetPlId() -> Could not find pl_id where $well, $sec_id, $pt_id.";
    return 0;
} #GetPlId

sub GetReagentName {
    
   my ($self, $barcode) = @_;
 
   my $reagentObj = GSC::ReagentInformation->get(barcode=>$barcode);

   if(defined $reagentObj) {
       return $reagentObj->reagent_name;
   }
   
   return 0;
   
}

sub GetPfPrimerId {

    my ($self, $barcode) = @_;
 
    my $reagentObj = GSC::ReagentInformation->get(barcode=>$barcode);

    if(defined $reagentObj) {

        my $pri_id;

        if($reagentObj->reagent_name =~ /FWD/) {
            $pri_id = $self -> GetPrimerId($barcode, 'forward');
        }
        else {
	    $pri_id = $self -> GetPrimerId($barcode, 'reverse');
        }

        return $pri_id;

    }

   return 0;

} #GetFwdPrimerId


sub GetPrimerId {

    my ($self, $barcode, $direction) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self->{'Schema'};

    my $sql = "select pri_id from primers where pri_id = 
               (select pri_pri_id from primers_reagent_names where rn_reagent_name =
               (select rn_reagent_name from reagent_informations where bs_barcode = '$barcode'))
               and pd_primer_direction = '$direction'";

    
    my $pri_id = Query($dbh, $sql);
 
    if($pri_id) {
	return $pri_id;
    }

    return 0;

} #GetPrimerId

sub GetPfDyeChemId {

    my ($self, $barcode) = @_;
 
    my $reagentObj = GSC::ReagentInformation->get(barcode=>$barcode);

    if(defined $reagentObj) {

        my $pri_id;

        if($reagentObj->reagent_name =~ /FWD/) {
	    $pri_id = $self -> GetDyeChemId($barcode, 'forward');
        }
        else {
	    $pri_id = $self -> GetDyeChemId($barcode, 'reverse');
        }

        return $pri_id;

    }

    return 0;

}

sub GetDyeChemId {

    my ($self, $barcode, $direction) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self->{'Schema'};

    my $sql = "select dc_dc_id from dye_chemistries_reagent_names where rn_reagent_name =
	       (select rn_reagent_name from reagent_informations where bs_barcode = '$barcode') and  
	       exists (select 'x' from primers where pri_id in (
               select pri_pri_id from primers_reagent_names where rn_reagent_name =  
               (select rn_reagent_name from reagent_informations where bs_barcode = '$barcode')
               and pd_primer_direction = '$direction'))";

    my $dc_id = Query($dbh, $sql);
 
    if($dc_id) {
	return $dc_id;
    }
    
    return 0;
    
}

sub GetPfEnzId {

    my ($self, $barcode) = @_;
 
    my $reagentObj = GSC::ReagentInformation->get(barcode=>$barcode);

    if(defined $reagentObj) {

        my $pri_id;

        if($reagentObj->reagent_name =~ /FWD/) {
	    $pri_id = $self -> GetEnzId($barcode, 'forward');
        }
        else {
	    $pri_id = $self -> GetEnzId($barcode, 'reverse');
        }

        return $pri_id;

    }

    return 0;

}


sub GetEnzId {

    my ($self, $barcode, $direction) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self->{'Schema'};

    my $sql = "select enz_enz_id from enzymes_reagent_names where rn_reagent_name =
	       (select rn_reagent_name from reagent_informations where bs_barcode = '$barcode') and  
	       exists (select 'x' from primers where pri_id in (
               select pri_pri_id from primers_reagent_names where rn_reagent_name =  
               (select rn_reagent_name from reagent_informations where bs_barcode = '$barcode')
               and pd_primer_direction = '$direction'))";

    
    my $enz_id = Query($dbh, $sql);
 
    if($enz_id) {
	return $enz_id;
    }

    
    return 0;

}



sub ComparePrimerReagentToAvailVector {

    my ($self, $reagent, $barcode) = @_;

    my $dbh = $self->{'dbh'};
    $self->{'ComparePrimerReagentToAvailVector'} = LoadSql($dbh, "select vl_vl_id from ligations where lig_id = (select lig_lig_id from subclones where 
               sub_id in (select max(sub_sub_id) from subclones_pses where pse_pse_id in (select 
               pse_pse_id from pse_barcodes where bs_barcode = ? and direction = 'out')))", 'Single');
    $self->{'CountVlIdReagent'} = LoadSql($dbh,  "select count(*) from reagent_vector_linearizations where vl_vl_id = ? and rn_reagent_name = ?", 'Single');
   
    

    my $subclone_vl_id = $self->{'ComparePrimerReagentToAvailVector'} -> xSql($barcode);

    unless ($subclone_vl_id) {

	my $bar = GSC::Barcode->get($barcode);
	my @dna = $bar->get_dna;
	my $vl = $dna[0]->get_vector_linearization;
	$subclone_vl_id = $vl->id;
    }

    if(defined $subclone_vl_id) {
	my $count = $self->{'CountVlIdReagent'} -> xSql($subclone_vl_id, $reagent);
	
	if($count > 0) {
	    return 1;
	}
	else {
	    $self->{'Error'} = "$pkg: ComparePrimerReagentToAvailVector() -> The reagent used is not valid for this type of ligation.";
	}
    }
    else {
	$self->{'Error'} = "$pkg: ComparePrimerReagentToAvailVector() -> Could not find the vl_id from the barcode = $barcode.";
    }

return 0;

}



sub GetDirSeqInfo {

    my ($self, $tbar) = @_;
   
    my $lol = $self->{'GetPreBarPseInfo'}->xSql($tbar);
    if(defined $lol && $lol->[0]) {
      foreach my $line (@{$lol}) {
        $tbar = $line->[0];
	last;
      }
    } else {
      $lol = $self->{'GetPreBarPse'}->xSql($tbar);
      if(defined $lol && $lol->[0]) {
	foreach my $line (@{$lol}) {
	  if($self ->{'CheckProcess'}->xSql($line->[1]) eq 'pick targeted subclones') {
	    last;
	  } else {
	    my @info = $self->GetDirSeqInfo($line->[0]);
	    if(@info && $info[0]) {
	      return @info;
	    }
	  }
	}
      } else {
	$self->{'Error'} = "$pkg: GetDirSeqInfo() -> Could not find direct_seq information for barcode = $tbar.";
	return (0);
      }
    }
    my $reaction_info = $self -> {'PrefinishDyeChem'} -> xSql($tbar);

    my %info = ('dye_name' => $reaction_info->[0][0],
		'dc_id' => $reaction_info->[0][1],
		'enzyme_name' => $reaction_info->[0][2],
		'enz_id' => $reaction_info->[0][3],
		'primer_direction' => $reaction_info->[0][4],
		'primer_type' => $reaction_info->[0][5],
		);
    return($tbar, %info);
    
} 

sub GetSubIdFromSubclone {
    
    my ($self, $subclone) = @_;
    
     my $sub_obj = GSC::Subclone->get(subclone_name=>$subclone);

    if(defined $sub_obj) {
	return ($sub_obj->sub_id);
    }

    $self -> {'Error'} = "$pkg: GetSubIdFromSubclone() -> Could not find sub_id for subclone = $subclone.";

    return 0;
}

sub GetPriIdFromPrimer {

    my ($self, $primer) = @_;

    my $pri_obj = GSC::Primer->get(primer_name=>$primer);

    if(defined $pri_obj) {
	return ($pri_obj->pri_id);
    }

    $self -> {'Error'} = "$pkg: GetPriIdFromPrimer() -> Could not find pri_id where primer_name = $primer.";

    return 0;
}

######################################
# Get the next ds_id sequence number #
######################################
sub GetNextDsId {

    my ($self) = @_;
    my $ds_id = Query($self->{'dbh'}, "select ds_seq.nextval from dual");
    if($ds_id) {
	return $ds_id;
    }
    $self->{'Error'} = "$pkg: GetNextDsId() -> Could not get next ds_id.";

    return 0;
 
} #GetNextDsId



############################################################################################
#                                                                                          #
#                                     Insert Subrotines                                    #
#                                                                                          #
############################################################################################




#################################################################
# Insert an sub_id, pse_id, pl_id into the subclones_pses table #
#################################################################
#sub InsertSubclonesPses {
#
#    my ($self, $pse_id, $sub_id, $pl_id) = @_;
#
#    my $result = $self -> {'InsertSubclonesPses'} -> xSql($pse_id, $sub_id, $pl_id);
#
#    if($result) {
#	return $result;
#    }
#    
#    $self->{'Error'} = "$pkg: InsertSubclonesPses() -> Could not insert $pse_id, $sub_id, $pl_id";
#    return 0;
#} #InsertSubclonesPses




####################################
# Insert Locations of Sequence DNA #
####################################
#sub InsertSeqDnaPses {
#
#    my ($self, $pse_id, $seqdna_id, $pl_id) = @_;
#
#    
#    my $result =$self->{'InsertSeqDnaPses'}->xSql($pse_id, $seqdna_id, $pl_id);
#
#    if($result) {
#	return $result;
#    }
#    $self->{'Error'} = "$pkg: InsertSeqDnaPses() -> Could not insert into seq_dna_pses where pse_id = $pse_id, seqdna_id = $seqdna_id, pl_id = $pl_id.";
#    return 0;
#} #SeqDnaLocationEvent

####################################
# Insert Locations of Sequence DNA #
####################################
sub InsertDirSeqDna {

    my ($self, $seqdna_id, $ds_id) = @_;

    
#    my $result =$self->{'InsertDirSeqDna'}->xSql($seqdna_id, $ds_id);
    my $result = GSC::DirSeqDNA -> create(seqdna_id => $seqdna_id,
					  ds_id =>  $ds_id);



    if($result) {
	return $result;
    }
    $self->{'Error'} = "$pkg: InsertDirSeqDna() -> Could not insert into dir_seq_dnas where seqdna_id = $seqdna_id, ds_id = $ds_id.";
    return 0;
} #InsertDirSeqDna

sub InsertSequencedDnas {

    my($self, $sub_id, $primer_id, $dye_chem_id, $enz_id, $seq_id, $pse_id, $dl_id, $ds_id) = @_;

#    my $result = $self->{'InsertSequencedDnas'} -> xSql($sub_id, $primer_id, $dye_chem_id, $enz_id, $seq_id);
    
    GSC::SeqDNA -> class;

    my $result = GSC::SeqDNA->create(pri_id        => $primer_id, 
				     dc_id         => $dye_chem_id,
				     enz_id        => $enz_id,
				     dna_id        => $seq_id, 
				     parent_dna_id => $sub_id,
				     pse_id        => $pse_id,
				     dl_id         => $dl_id,
                                     ds_id         => $ds_id
                                     );

    if($result) {

	return $result;
    }

    $self->{'Error'} = "$pkg: InsertSequencedDnas() -> $sub_id, $primer_id, $dye_chem_id, $enz_id, $seq_id.";
    return 0;
} #InsertSequencedDnas



sub InsertDirectSeq {

    my ($self, $enz_id, $pri_id, $dc_id, $sub_id, $project, $ds_id, $trace_name) = @_;

    
#    my $result = $self -> {'InsertDirectSeq'} -> xSql($enz_id, $pri_id, $dc_id, $sub_id, $project, $ds_id, $trace_name);
    my $result = GSC::DirectSeq->create(enz_id => $enz_id,
					pri_id => $pri_id, 
					dc_id => $dc_id,
					dna_id => $sub_id, 
					seqmgr_directory => $project, 
					ds_id => $ds_id, 
					trace_name => $trace_name);


    if($result) {
	return $result;
    }

    $self -> {'Error'} = "$pkg: InserDirectSeq() -> Could not insert into direct_seq table.";
    return 0;
}

sub InsertDirectSeqPses {

    my ($self, $new_pse, $ds_id) = @_;

#    my $result = $self -> {'InsertDirectSeqPses'} -> xSql($ds_id, $new_pse);

    my $result = GSC::DirectSeqPSE -> create(pse_id => $new_pse, 
					     ds_id => $ds_id);


    return $result if($result);

    $self -> {'Error'} = "$pkg: InsertDirectSeqPses() -> Failed to insert into direct_seq_pses.";
    return 0;
}



####################################
# Create sequence dna informations #
####################################
sub CreateSequenceDna {
    
    my ($self, $barcode, $pre_pse_id, $dye_chem_id, $primer_id, $enz_id, $pt_id, $sec_id, $new_pse_id) = @_;

    #my $well_count = $self->GetWellCount($pt_id);
    #return 0 if($well_count == 0);

    my $sector = $self -> GetSectorName($sec_id); 
    return 0 if($sector eq '0');
    
    my $lol =  $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($barcode, $pre_pse_id);
    if(! defined $lol->[0][0]) {
	$lol =  $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($barcode, $pre_pse_id);
	return 0 if(! defined $lol->[0][0]);
    }

    foreach my $row (@{$lol}) {
	my $sub_id = $row->[0];
	my $well_96 = $row->[1];
	my $pl_id = $row->[2];
	
	my $seq_id = $self->GetNextSeqdnaId;
	#if($well_count eq '384') {
	if($pt_id eq '384 well plate') {
		    
	    my $well_384 = &ConvertWell::To384 ($well_96, $sector);
	    
	    $pl_id = $self->GetPlId($well_384, $sec_id, $pt_id);
	    return 0 if($pl_id eq '0');
	}
	
        # insert subclone into table
	my $result = $self->InsertSequencedDnas($sub_id, $primer_id, $dye_chem_id, $enz_id, $seq_id, $new_pse_id, $pl_id);
	return 0 if(!$result);
	

#	$result = $self -> InsertSeqDnaPses($new_pse_id, $seq_id, $pl_id);
#	return 0 if ($result == 0);
    }	

    return 1;
   
} #SequenceDnaCreation



sub aliquotOligo {   
   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   my $lol = $self -> {'GetAvailOligoOutInprogress'} ->xSql("out", $bars_in->[0], $ps_id);
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
   my %hash;
   my $pses = [];
   
   foreach my $data (@{$lol}) {
     my($pri_pri_id, $pse_id,  $dl_id, $dna_id, $bs_barcode, $direction, $location_name) = @$data;
     $location_name =~ /(\d+)/;
     push @{$hash{$1}}, $data;
   }
   for(my $i = 0; $i < @{$bars_out}; $i ++) {
     my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_ids->[0], $update_status, $update_result, $bars_in->[0], [$bars_out->[$i]], $emp_id);
     my $col = sprintf("%02d", $i + 1);
     if(defined $hash{$col}) {
       $self->Trans8To96($bars_out->[$i], $pre_pse_ids->[0], $new_pse_id, $hash{$col});
   }
     
     push(@$pses, $new_pse_id);
   }

   return $pses;
}

##########################################################
# Log a transfer from 8 to 96 subclone locations event   #
##########################################################
sub Trans8To96 {

    my ($self, $barcode, $pre_pse_id, $new_pse_id, $data) = @_;
    #Get the the dl location for a 96 well plate.
    #
    #$rowHash{$row}->{$col} = $dl_id;
    my %rowHash;
    my $dls = LoLquery($self->{dbh}, qq/select dl_id, location_name from dna_location where location_type = '96 well plate'/);
    foreach my $r (@$dls) {
      $r->[1] =~ /([a-z])(\d+)/;
      $rowHash{$1}->{$2} = $r->[0];
    }

    foreach my $d (@$data) {
      my($pri_pri_id, $pse_id,  $dl_id, $dna_id, $bs_barcode, $direction, $location_name) = @$d;
      my ($row) = $location_name =~ /([a-z])/;
      #Find the $ndl_id
      #From 96 well plate location, find the row dl_id.
      for(my $i = 1; $i <= 12; $i ++) {
        if($row eq "h" && $i == 12) {
	  next;
	}

	my $pos = $i;
	$pos = '0'.$pos if($i < 10);

	my $result = GSC::CustomPrimerPSE->create(pse_id => $new_pse_id, 
						  dl_id => $rowHash{$row}->{$pos}, 
						  dna_id => $dna_id, 
						  pri_id => $pri_pri_id);
	if(! $result) {
	  $self->{'Error'} = "$pkg: Trans8To96() -> Transfer 8 to 96 error [pse_pse_id => $new_pse_id, dl_id => $dl_id, dna_id => $dna_id, pri_pri_id => $pri_pri_id].";
	}
      }
    }
#    return 0 if(! App::DB->sync_database);
#    App::DB->commit;
    return 1;

} #Trans96To384

1;

# $Header$
