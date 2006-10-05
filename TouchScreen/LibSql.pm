# -*-Perl-*-

##############################################
# Copyright (C) 2001 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

package TouchScreen::LibSql;

use strict;
use DBI;
use DbAss;
use TouchScreen::CoreSql;
use TouchScreen::TouchSql;
use BarcodeImage;
use TouchScreen::GelImageLogSheet;

#############################################################
# Production sql code package
#############################################################

require Exporter;


our @ISA = qw (Exporter AutoLoader);
our @EXPORT = qw ( New );

my $pkg = __PACKAGE__;
my $GelPositions1 =  ['Marker 1', 'Lane 1', 'Lane 2', 'Lane 3', 'Lane 4', 'Lane 5', 'Lane 6', 'Lane 7', 'Lane 8', 'Lane 9', 'Lane 10', 'Lane 11' , 'Lane 12', 'Lane 13', 'Lane 14', 'Lane 15', 'Lane 16'];
my $GelPositions2 = ['Marker 1', 'Marker 2', 'Lane 1', 'Lane 2', 'Lane 3', 'Lane 4', 'Lane 5', 'Lane 6', 'Lane 7', 'Lane 8', 'Lane 9', 'Lane 10', 'Lane 11' , 'Lane 12', 'Lane 13', 'Lane 14', 'Lane 15', 'Lane 16'];
my $GelPositions3 = ['Marker 1', 'Marker 2', 'Marker 3', 'Lane 1', 'Lane 2', 'Lane 3', 'Lane 4', 'Lane 5', 'Lane 6', 'Lane 7', 'Lane 8', 'Lane 9', 'Lane 10', 'Lane 11' , 'Lane 12', 'Lane 13', 'Lane 14', 'Lane 15', 'Lane 16'];
my $FractionGelPositions = ['Lane 1', 'Lane 2', 'Lane 3', 'Lane 4', 'Lane 5', 'Lane 6', 'Lane 7', 'Lane 8', 'Lane 9', 'Lane 10', 'Lane 11' , 'Lane 12', 'Lane 13', 'Lane 14', 'Lane 15', 'Lane 16', 'Lane 17', 'Lane 18', 'Lane 19', 'Lane 20', 'Lane 21' , 'Lane 22', 'Lane 23', 'Lane 24'];

#########################################################
# Create a new instance of the LibSql code so that you #
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
    $self->{'printer'} = 'barcode1';
      

    $self->{'CoreSql'} = TouchScreen::CoreSql->new($dbh, $schema);
#   $self->{'InsertProjects'} = LoadSql($dbh,"insert into projects (project_id, pp_purpose, target, priority, name, prosta_project_status) 
#                                                 values (?, ?, ?, ?, ?, ?)");
    
#    $self->{'InsertCloneGrowths'} = LoadSql($dbh,"insert into clone_growths (cg_id, growth_ext, clo_clo_id, location_library_core, cg_cg_id, growth_purpose) values (?, ?, ?, ?, ?, ?)");
#    $self->{'InsertCloneGrowthsLibraries'} = LoadSql($dbh,"insert into clone_growths_libraries (cg_cg_id, cl_cl_id) values (?, ?)");

#    $self->{'InsertCloneLibraries'} = LoadSql($dbh,"insert into clone_libraries (cl_id, library_number) values (?, ?)");
#    $self->{'InsertFractions'} = LoadSql($dbh,"insert into fractions (fra_id, fraction_name, fraction_size, cl_cl_id, min_base_length, max_base_length) values (?, ?, ?, ?, ?, ?)");
#   $self->{'InsertLigations'} = LoadSql($dbh,"insert into Ligations (lig_id, ligation_name, vl_vl_id, fra_fra_id, fraction_volume_ligated) values (?, ?, ?, ?, ?)");

#    $self->{'InsertProjectsPses'} = LoadSql($dbh,"insert into projects_pses (project_project_id, pse_pse_id) values (?, ?)");
#    $self->{'InsertClonesProjects'} = LoadSql($dbh,"insert into clones_projects (clo_clo_id, project_project_id) values (?, ?)");
#    $self->{'InsertProjectStatusHistory'} = LoadSql($dbh,"insert into project_status_histories (project_project_id, ps_project_status, status_date) values (?, ?, sysdate)");
#    $self->{'InsertClonesPses'} = LoadSql($dbh,"insert into clones_pses (clo_clo_id, pse_pse_id) values (?, ?)");
#   $self->{'InsertCloneGrowthsPses'} = LoadSql($dbh,"insert into clone_growths_pses (cg_cg_id, pse_pse_id, pl_pl_id) values (?, ?, ?)");
#   $self->{'InsertCloneLibrariesPses'} = LoadSql($dbh,"insert into clone_libraries_pses (cl_cl_id, pse_pse_id, gel_lane) values (?, ?, ?)");
#   $self->{'InsertFractionsPses'} = LoadSql($dbh,"insert into fractions_pses (fra_fra_id, pse_pse_id, gel_lane) values (?, ?, ?)");
#   $self->{'InsertLigationsPses'} = LoadSql($dbh,"insert into dna_pse (lig_lig_id, pse_pse_id, gel_lane) values (?, ?, ?)");
#   $self->{'InsertSubclonesPses'} = LoadSql($dbh,"insert into subclones_pses (sub_sub_id, pse_pse_id, gel_lane, pl_pl_id) values (?, ?, ?, ?)");


    $self->{'GetCgIdFromPse'} = LoadSql($dbh,"select cg_cg_id from clone_growths_pses where pse_pse_id = ?", 'Single');    
    $self->{'GetCgIdsFromPse'} = LoadSql($dbh,"select cg_cg_id, pl_pl_id from clone_growths_pses where pse_pse_id = ?", 'List');    
    $self->{'GetClIdFromPse'} = LoadSql($dbh,"select cl_cl_id from clone_libraries_pses where pse_pse_id = ?", 'Single');    
    $self->{'GetFraIdFromPse'} = LoadSql($dbh,"select fra_fra_id from fractions_pses where pse_pse_id = ?", 'Single');    
    $self->{'GetLigIdFromPse'} = LoadSql($dbh,"select lig_lig_id from ligations_pses where pse_pse_id = ?", 'Single');    
    $self->{'GetSubIdFromPse'} = LoadSql($dbh,"select sub_sub_id from subclones_pses where pse_pse_id = ?", 'Single');    

    $self->{'GetCgIdFromSubId'} = LoadSql($dbh,"select cg_cg_id from clone_growths_libraries cgl, fractions fr, ligations, subclones where sub_id = ? and
                                                    lig_id = lig_lig_id and fra_id = fra_fra_id and cgl.cl_cl_id = fr.cl_cl_id", 'Single');    


    $self->{'GetAvailClone'} = LoadSql($dbh,"
               select distinct clo.clone_name, pse.pse_id
               from 
	       clones clo, 
               clones_pses clox, 
               pse_barcodes barx, process_step_executions pse, process_steps ps where
               clo.clo_id = clox.clo_clo_id and
               pse.pse_id = clox.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = 'inprogress' and 
               barx.bs_barcode = ? and barx.direction = 'out' and pse.ps_ps_id = ps.ps_id 
               and ps.ps_id in (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?))", 'ListOfList');

    $self->{'GetAvailCloneGrowth'} = LoadSql($dbh, "select distinct clo.clone_name, cg.growth_ext, pse.pse_id
               from 
	       clones clo, clone_growths cg, 
               clone_growths_pses cgx,
               pse_barcodes barx, process_step_executions pse, process_steps ps where
               clo.clo_id = cg.clo_clo_id and
               cg.cg_id = cgx.cg_cg_id and
               pse.pse_id = cgx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id = ps.ps_id 
               and ps.ps_id in (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = (select purpose from process_steps where ps_id = ?))", 'ListOfList');

    $self->{'GetAvailCloneGrowthToSonicate'} = LoadSql($dbh, "select distinct clo.clone_name, cg.growth_ext, pse.pse_id
               from 
	       clones clo, clone_growths cg, 
               clone_growths_pses cgx,
               pse_barcodes barx, process_step_executions pse, process_steps ps where
               clo.clo_id = cg.clo_clo_id and
               cg.cg_id = cgx.cg_cg_id and
               pse.pse_id = cgx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id = ps.ps_id 
               and ps.ps_id in (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = (select purpose from process_steps where ps_id = ?)) and 
               cg_id = (select cg_cg_id from clone_growths_pses cg, pse_barcodes pb where 
               cg.pse_pse_id = pb.pse_pse_id and direction = 'out' and bs_barcode = ?)", 'ListOfList');
    
    $self->{'GetAvailLibraryGelCheck'} = LoadSql($dbh, "select c.clone_name, cl.library_number, pse.pse_id from 
clone_libraries cl, 
process_steps ps,process_step_executions pse, process_steps ps1, process_step_executions pse1,  
pse_barcodes pb, pse_barcodes pb1, dna_pse dp, dna_pse dp1,
dna_relationship dr,
clone_growths cg,
clones c
where 
  c.clo_id = cg.clo_clo_id
and
  cg.cg_id = dr.parent_dna_id
and
  dr.dna_id = dp1.dna_id
and
  dr.dna_id = cl.cl_id
and
  pb1.pse_pse_id = dp1.pse_id
and
  dp1.pse_id = pse1.pse_id
and
  ps1.ps_id = pse1.ps_ps_id
and
  dp1.dna_id = dp.dna_id
and
  pse.pse_id = dp.pse_id
and
  pb.pse_pse_id = pse.pse_id 
and 
  ps.ps_id = pse.ps_ps_id
and
  pse.psesta_pse_status = ? 
and
  pse.pr_pse_result = ?
and
  pb1.bs_barcode = ?
and
  pb1.direction = ?
and
  pse.ps_ps_id in
               (select ps1.ps_id from process_steps ps1, process_steps ps2 where ps1.pro_process_to = ps2.pro_process and
               ps2.ps_id = ? and
                ps2.purpose = ps1.purpose)", 'ListOfList');
		
    $self->{'GetAvailLibraryGelCheckInfo'} = LoadSql($dbh, "select 
  c.clone_name, cl.library_number, pse.pse_id
from 
process_steps ps,process_step_executions pse, 
pse_barcodes pb, pse_barcodes pb1, clone_libraries cl, 
dna_pse dp, dna_pse dp1,
dna_relationship dr,
clone_growths cg,
clones c
where 
  c.clo_id = cg.clo_clo_id
and
  cg.cg_id = dr.parent_dna_id
and
  dr.dna_id = dp1.dna_id
and
  dr.dna_id = cl.cl_id
and
  pb1.pse_pse_id = dp1.pse_id
and
  dp1.dna_id = dp.dna_id
and
  pse.pse_id = dp.pse_id
and
  pb.pse_pse_id = pse.pse_id 
and 
  ps.ps_id = pse.ps_ps_id
and
  pb1.direction = 'out'
and  
  pse.pse_id = ?
and
  pse.ps_ps_id = ps.ps_id", 'ListOfList');
  
     $self->{'GetAvailLibraryPSEGelCheck'} = LoadSql($dbh, "select distinct pse.pse_id from process_steps ps1, process_steps ps, process_step_executions pse, pse_barcodes pb where 
pb.pse_pse_id =  pse.pse_id and
ps.pro_process_to = ps1.pro_process and
ps1.ps_id = ? and
pse.psesta_pse_status = ? and
pse.pr_pse_result = ? and
ps.ps_id = pse.ps_ps_id and pse.pse_id in (
select pse_id from process_step_executions pse
start with pse.pse_id = (
select pse.pse_id from pse_barcodes pb, process_steps ps, process_step_executions pse
where
  pb.pse_pse_id = pse.pse_id
and
  ps.ps_id = pse.ps_ps_id
and
  pb.bs_barcode = ?
and
  pb.direction = ?
)
connect by prior pse.pse_id = pse.prior_pse_id)", 'ListOfList');   
		
    $self->{'GetAvailLibraryGelCheck_old'} = LoadSql($dbh, "select distinct clone_name, library_number, pse.pse_id
               from 
	       clones clo, clone_growths cg, 
               clone_growths_libraries cgl,
	       clone_libraries cl,  
               clone_libraries_pses clx,
               pse_barcodes barx, process_step_executions pse where
               clo.clo_id = cg.clo_clo_id and
               cgl.cg_cg_id = cg.cg_id and
               cgl.cl_cl_id = cl.cl_id and
               cl.cl_id = clx.cl_cl_id and
               pse.pse_id = clx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               pse.pr_pse_result = ? and 
               cl.cl_id in (
                   select cl_cl_id from clone_libraries_pses clx, pse_barcodes barx where 
                   barx.bs_barcode = ? and barx.direction = ? and clx.pse_pse_id = barx.pse_pse_id) 
               and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = (select purpose from process_steps where ps_id = ?))", 'ListOfList');
    
    $self->{'GetAvailFractionGelCheck'} = LoadSql($dbh, "select distinct clone_name, library_number, fraction_name, pse.pse_id
               from 
	       clones clo, clone_growths cg, 
               clone_growths_libraries cgl,
	       clone_libraries cl,  
               fractions fr,
               fractions_pses frx,
               pse_barcodes barx, process_step_executions pse where
               clo.clo_id = cg.clo_clo_id and
               cgl.cg_cg_id = cg.cg_id and
               cgl.cl_cl_id = cl.cl_id and
               cl.cl_id = fr.cl_cl_id and
               fr.fra_id = frx.fra_fra_id and 
               pse.pse_id = frx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               pse.pr_pse_result = ? and 
               fr.fra_id = (
                   select fra_fra_id from fractions_pses frx, pse_barcodes barx where 
                   barx.bs_barcode = ? and barx.direction = ? and frx.pse_pse_id = barx.pse_pse_id) 
               and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose in (select purpose from process_steps where ps_id = ?))", 'ListOfList');
 
   $self->{'GetAvailLigationGelCheck'} = LoadSql($dbh, "select distinct clone_name, CHR_CHROMOSOME, library_number, ligation_name, pse.pse_id
               from 
	       clones clo, clone_growths cg, 
               clone_growths_libraries cgl,
	       clone_libraries cl,  
               fractions fr,
               ligations lg, 
               dna_pse lgx,
               pse_barcodes barx, process_step_executions pse where
               clo.clo_id = cg.clo_clo_id and
               cgl.cg_cg_id = cg.cg_id and
               cgl.cl_cl_id = cl.cl_id and
               cl.cl_id = fr.cl_cl_id and
               lg.fra_fra_id = fr.fra_id and
               lg.lig_id = lgx.dna_id and
               pse.pse_id = lgx.pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               pse.pr_pse_result = ? and 
               lg.lig_id = (
                   select dna_id from dna_pse lgx, pse_barcodes barx where 
                   barx.bs_barcode = ? and barx.direction = ? and lgx.pse_id = barx.pse_pse_id) 
               and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = ?)", 'ListOfList');
    
    $self -> {'CountGrowthsInPlate'} = LoadSql($dbh, "select count(*) from clone_growths_pses 
              where pse_pse_id in (select distinct pse_pse_id from pse_barcodes 
              where bs_barcode = ? and direction = 'out')", 'Single');

    $self->{'GetAvailGrowthForArchive'} = LoadSql($dbh, "select distinct clo.clone_name, cg.growth_ext, pse.pse_id 
               from 
	       clones clo, clone_growths cg, 
               dna_pse cgx,
               pse_barcodes barx, process_step_executions pse where
               clo.clo_id = cg.clo_clo_id and
               cg.cg_id = cgx.dna_id and
               pse.pse_id = cgx.pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and ps_ps_id in (
                  select ps_id from process_steps where pro_process_to = 'finalize dna')
               and cg.cg_id in (select cg_cg_id from 
               clone_growths_pses, process_step_executions where pse_id = pse_pse_id 
               and psesta_pse_status = 'inprogress' and ps_ps_id  = ?)", 'ListOfList');


    $self->{'GetAvailLibrary'} = LoadSql($dbh, "select distinct clone_name, library_number, pse.pse_id
               from 
	       clones clo, clone_growths cg, 
               clone_growths_libraries cgl,
	       clone_libraries cl,  
               clone_libraries_pses clx,
               pse_barcodes barx, process_step_executions pse where
               clo.clo_id = cg.clo_clo_id and
               cgl.cg_cg_id = cg.cg_id and
               cgl.cl_cl_id = cl.cl_id and
               cl.cl_id = clx.cl_cl_id and
               pse.pse_id = clx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = (select purpose from process_steps where ps_id = ?))", 'ListOfList');
    $self->{'GetAvailFraction'} = LoadSql($dbh, "select distinct clone_name, library_number, fraction_name, pse.pse_id
               from 
	       clones clo, clone_growths cg, 
               clone_growths_libraries cgl, 
	       clone_libraries cl, fractions fr,
               fractions_pses frx,
               pse_barcodes barx, process_step_executions pse where
               clo.clo_id = cg.clo_clo_id and
               cgl.cg_cg_id = cg.cg_id and
               cgl.cl_cl_id = cl.cl_id and
               fr.cl_cl_id = cl.cl_id and
               frx.fra_fra_id = fr.fra_id and
               pse.pse_id = frx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose in ('New Library Construction', 'Library Construction', 'Ligation', 'Transition Non-Barcoded Library Core', 'Restriction Digest Subcloning', 'Shatter'))", 'ListOfList');
    $self->{'GetAvailLigation'} = LoadSql($dbh, "select distinct library_number, ligation_name, pse.pse_id
               from 
	       clone_libraries cl, fractions fr, ligations lg,
               dna_pse lgx,
               pse_barcodes barx, process_step_executions pse where
               lgx.dna_id = lg.lig_id and
               fr.fra_id = lg.fra_fra_id and
               fr.cl_cl_id = cl.cl_id and
               pse.pse_id = lgx.pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose in ((select purpose from process_steps where ps_id = ?), 'Transition Non-Barcoded Library Core'))", 'ListOfList');
    $self->{'GetAvailLigationType'} = LoadSql($dbh, "select distinct library_number, ligation_name, pse.pse_id
               from 
	       clone_libraries cl, fractions fr, ligations lg,
               dna_pse lgx,
               pse_barcodes barx, process_step_executions pse where
               lgx.dna_id = lg.lig_id and
               fr.fra_id = lg.fra_fra_id and
               fr.cl_cl_id = cl.cl_id and
               pse.pse_id = lgx.pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               (pr_pse_result = 'successful' or pr_pse_result is NULL) and
               barx.bs_barcode = ? and barx.direction = ? and
               lg.vl_vl_id in (select vl_id from vector_linearizations where vec_vec_id in (select vec_id from vectors where vt_vector_type like ?)) and
               pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?))", 'ListOfList');
    $self->{'GetAvailLigationToClaim'} = LoadSql($dbh, "select distinct library_number, ligation_name, pse.pse_id
               from 
	       clone_libraries cl, fractions fr, ligations lg,
               dna_pse lgx,
               pse_barcodes barx, process_step_executions pse where
               lgx.dna_id = lg.lig_id and
               fr.fra_id = lg.fra_fra_id and
               fr.cl_cl_id = cl.cl_id and
               pse.pse_id = lgx.pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?)) and
               lg.vl_vl_id in (select vl_id from vector_linearizations where vec_vec_id in 
               (select vec_id from vectors where vt_vector_type = 'filamentous phage'))", 'ListOfList');

    $self->{'GetAvailAgarPlate'} = LoadSql($dbh, "select distinct library_number, ligation_name, pse.pse_id
               from 
	       clone_libraries cl, fractions fr, ligations lg,
               dna_pse lgx,
               pse_barcodes barx, process_step_executions pse where
                lgx.dna_id = lg.lig_id and
               fr.fra_id = lg.fra_fra_id and
               fr.cl_cl_id = cl.cl_id and
               pse.pse_id = lgx.pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose =  ?)", 'ListOfList');

    $self->{'GetAvailAgarPlateToFail'} = LoadSql($dbh, "select distinct library_number, ligation_name, pse.pse_id
               from 
	       clone_libraries cl, fractions fr, ligations lg,
               dna_pse lgx,
               pse_barcodes barx, process_step_executions pse where
                lgx.dna_id = lg.lig_id and
               fr.fra_id = lg.fra_fra_id and
               fr.cl_cl_id = cl.cl_id and
               pse.pse_id = lgx.pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where       
                purpose =  ?)", 'ListOfList');


    $self->{'GetProjectTargetFromBarcodePsId'} = LoadSql($dbh, "select distinct projects.target from 
               projects, clones_projects, clone_growths, fractions, 
               clone_growths_libraries cgl, 
               ligations, dna_pse, pse_barcodes, process_step_executions pse, process_steps where
               project_id = project_project_id and 
               clone_growths.clo_clo_id = clones_projects.clo_clo_id and  
               clone_growths.cg_id = cgl.cg_cg_id and
               fractions.cl_cl_id = cgl.cl_cl_id and
               fra_id = fra_fra_id and lig_id = dna_id and pse_barcodes.pse_pse_id = dna_pse.pse_id and 
               pse_barcodes.pse_pse_id = pse.pse_id and ps_ps_id = ps_id and
               bs_barcode = ? and direction = 'out' and
               ps_id in (select ps_id from process_steps where pro_process_to in (select pro_process from process_steps where ps_id = ?))", 'Single');

    $self->{'GetProjectPurposeFromBarcodePsId'} = LoadSql($dbh, "select distinct  projects.pp_purpose from 
               projects, clones_projects, clone_growths, fractions, 
               clone_growths_libraries cgl, 
               ligations, dna_pse, pse_barcodes, process_step_executions pse, process_steps where
               project_id = project_project_id and clone_growths.clo_clo_id = clones_projects.clo_clo_id and  
               clone_growths.cg_id = cgl.cg_cg_id and
               fractions.cl_cl_id = cgl.cl_cl_id and
               fra_id = fra_fra_id and lig_id = dna_id and pse_barcodes.pse_pse_id = dna_pse.pse_id and 
               pse_barcodes.pse_pse_id = pse.pse_id and ps_ps_id = ps_id and
               bs_barcode = ? and direction = 'out' and
               ps_id in (select ps_id from process_steps where pro_process_to in (select pro_process from process_steps where ps_id = ?))", 'Single');

    $self->{'GetProjectPriorityFromBarcodePsId'} = LoadSql($dbh, "select distinct projects.priority from 
               projects, clones_projects, clone_growths, fractions, 
               clone_growths_libraries cgl, 
               ligations, dna_pse, pse_barcodes, process_step_executions pse, process_steps where
               project_id = project_project_id and  clone_growths.clo_clo_id = clones_projects.clo_clo_id and 
               clone_growths.cg_id = cgl.cg_cg_id and
               fractions.cl_cl_id = cgl.cl_cl_id and
               fra_id = fra_fra_id and lig_id = dna_id and pse_barcodes.pse_pse_id = dna_pse.pse_id and 
               pse_barcodes.pse_pse_id = pse.pse_id and ps_ps_id = ps_id and
               bs_barcode = ? and direction = 'out' and
               ps_id in (select ps_id from process_steps where pro_process_to in (select pro_process from process_steps where ps_id = ?))", 'Single');
	
    $self->{'GetPsoDescription'} = LoadSql($dbh, "select OUTPUT_DESCRIPTION from process_step_outputs where pso_id = ?", 'Single');
    
    $self -> {'GetPsesForFinalDnaArchivePlate'} = LoadSql($dbh, "select distinct pse_pse_id from pse_barcodes 
              where bs_barcode = '?' and direction = 'out'", 'List');

    $self->{'GetLibraryOnGel'} = LoadSql($self->{'dbh'}, "select gel_lane, library_number, clone_name, library_set from 
                       clones, clone_growths, clone_growths_libraries, clone_libraries, clone_libraries_pses where 
                       cl_id = clone_growths_libraries.cl_cl_id and cl_id = clone_libraries_pses.cl_cl_id and cg_id = clone_growths_libraries.cg_cg_id and 
                       clo_id = clo_clo_id and
                       pse_pse_id = ? order by gel_lane", 'ListOfList');
    $self->{'GetFractionOnGel'} = LoadSql($self->{'dbh'}, "select gel_lane, library_number, clone_name, library_set, fraction_name from 
                       clones, clone_growths, clone_growths_libraries, clone_libraries, fractions, fractions_pses where 
                       clo_id = clo_clo_id and
                       cl_id = clone_growths_libraries.cl_cl_id and 
                       cg_id = clone_growths_libraries.cg_cg_id and 
                       cl_id = fractions.cl_cl_id and
                       fra_id = fra_fra_id and 
                       pse_pse_id = ? order by gel_lane", 'ListOfList');

    $self->{'GetLigationOnGel'} = LoadSql($self->{'dbh'}, "select gel_lane, library_number, clone_name, library_set, ligation_name from 
                       clones, clone_growths, clone_growths_libraries, clone_libraries, fractions, ligations, ligations_pses where 
                       clo_id = clo_clo_id and
                       cl_id = clone_growths_libraries.cl_cl_id and 
                       cg_id = clone_growths_libraries.cg_cg_id and 
                       cl_id = fractions.cl_cl_id and
                       fra_id = fra_fra_id and 
                       lig_id = lig_lig_id and
                       pse_pse_id = ? order by gel_lane", 'ListOfList');

#    $self->{'GetSubcloneOnGel'} = LoadSql($self->{'dbh'}, "select gel_lane, clone_name, subclone_name from 
#                       clones, clone_growths, clone_growths_libraries, clone_libraries, fractions, ligations, subclones, subclones_pses subx where 
#                       clo_id = clo_clo_id and
#                       cl_id = clone_growths_libraries.cl_cl_id and 
#                       cg_id = clone_growths_libraries.cg_cg_id and 
#                       cl_id = fractions.cl_cl_id and
#                       fra_id = fra_fra_id and 
#                       lig_id = lig_lig_id and
#                       sub_id = subx.sub_sub_id and
#                       pse_pse_id = ? order by gel_lane", 'ListOfList');

    $self->{'GetAvailLibraryGel'} = LoadSql($dbh, "select distinct gel_lane, pse.pse_id
               from 
	       clones clo, clone_growths cg, 
               clone_growths_libraries cgl,
	       clone_libraries cl,  
               clone_libraries_pses clx,
               pse_barcodes barx, process_step_executions pse where
               clo.clo_id = cg.clo_clo_id and
               cgl.cg_cg_id = cg.cg_id and
               cgl.cl_cl_id = cl.cl_id and
               cl.cl_id = clx.cl_cl_id and
               pse.pse_id = clx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = (select purpose from process_steps where ps_id = ?)) order by gel_lane", 'ListOfList');

    $self->{'GetAvailFractionGel'} = LoadSql($dbh, "select distinct gel_lane, pse.pse_id
               from 
	       clones clo, clone_growths cg, 
               clone_growths_libraries cgl,
	       clone_libraries cl,  
               fractions fr,
               fractions_pses frx,
               pse_barcodes barx, process_step_executions pse where
               clo.clo_id = cg.clo_clo_id and
               cgl.cg_cg_id = cg.cg_id and
               cgl.cl_cl_id = cl.cl_id and
               cl.cl_id = fr.cl_cl_id and
               frx.fra_fra_id = fr.fra_id and
               pse.pse_id = frx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = (select purpose from process_steps where ps_id = ?)) order by gel_lane", 'ListOfList');
    $self->{'GetAvailLigationGel'} = LoadSql($dbh, "select distinct gel_lane, pse.pse_id
               from 
	       clones clo, clone_growths cg, 
               clone_growths_libraries cgl,
	       clone_libraries cl,  
               fractions fr,
               ligations lg,
               ligations_pses lgx,
               pse_barcodes barx, process_step_executions pse where
               clo.clo_id = cg.clo_clo_id and
               cgl.cg_cg_id = cg.cg_id and
               cgl.cl_cl_id = cl.cl_id and
               cl.cl_id = fr.cl_cl_id and
               lg.fra_fra_id = fr.fra_id and
               lgx.lig_lig_id = lg.lig_id and
               pse.pse_id = lgx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = (select purpose from process_steps where ps_id = ?)) order by gel_lane", 'ListOfList');
   
#    $self->{'GetAvailSubcloneGel'} = LoadSql($dbh, "select distinct gel_lane, pse.pse_id
#               from 
#	       clones clo, clone_growths cg, 
#               clone_growths_libraries cgl,
#	       clone_libraries cl,  
#               fractions fr,
#               ligations lg,
#               subclones,
#               subclones_pses subx,
#              pse_barcodes barx, process_step_executions pse where
#              clo.clo_id = cg.clo_clo_id and
#              cgl.cg_cg_id = cg.cg_id and
#              cgl.cl_cl_id = cl.cl_id and
#              cl.cl_id = fr.cl_cl_id and
#              lg.fra_fra_id = fr.fra_id and
#              lig_lig_id = lg.lig_id and
#              sub_id = subx.sub_sub_id and
#              pse.pse_id = subx.pse_pse_id and
#              barx.pse_pse_id = pse.pse_id and
#              pse.psesta_pse_status = ? and
#              barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
#              (select ps_id from process_steps where pro_process_to in
#              (select pro_process from process_steps where ps_id = ?) and      
#               purpose = (select purpose from process_steps where ps_id = ?)) order by gel_lane", 'ListOfList');

    $self->{'GetLibraryCloneSetFromPse'} = LoadSql($self->{'dbh'}, "select library_number, clone_name, library_set from 
                       clones, clone_growths, clone_growths_libraries, clone_libraries, clone_libraries_pses where 
                       cl_id = clone_growths_libraries.cl_cl_id and cl_id = clone_libraries_pses.cl_cl_id and cg_id = clone_growths_libraries.cg_cg_id and clo_id = clo_clo_id and
                       pse_pse_id = ? order by gel_lane", 'ListOfList');

    $self->{'GetLibraryCloneSetFractionFromPse'} = LoadSql($self->{'dbh'}, "select library_number, clone_name, library_set, fraction_name from 
                       clones, clone_growths, clone_growths_libraries, clone_libraries, fractions, fractions_pses where 
                       cl_id = clone_growths_libraries.cl_cl_id and cg_id = clone_growths_libraries.cg_cg_id 
                       and clo_id = clo_clo_id and fractions.cl_cl_id = cl_id and fra_id = fra_fra_id and 
                       pse_pse_id = ? order by gel_lane", 'ListOfList');

    $self->{'GetLibraryCloneSetLigationFromPse'} = LoadSql($self->{'dbh'}, "select library_number, clone_name, library_set, ligation_name from 
                       clones, clone_growths, clone_growths_libraries, clone_libraries, fractions, ligations, ligations_pses where 
                       cl_id = clone_growths_libraries.cl_cl_id and cg_id = clone_growths_libraries.cg_cg_id 
                       and clo_id = clo_clo_id and fractions.cl_cl_id = cl_id and fra_id = fra_fra_id and 
                       lig_id = lig_lig_id and 
                       pse_pse_id = ? order by gel_lane", 'ListOfList');

#   $self->{'GetSubcloneCloneFromPse'} = LoadSql($self->{'dbh'}, "select subclone_name, clone_name, library_number  from 
#                      clones, clone_growths, clone_growths_libraries, clone_libraries, fractions, ligations, subclones, subclones_pses subx where 
#                      cl_id = clone_growths_libraries.cl_cl_id and cg_id = clone_growths_libraries.cg_cg_id 
#                      and clo_id = clo_clo_id and fractions.cl_cl_id = cl_id and fra_id = fra_fra_id and 
#                      lig_id = lig_lig_id and sub_id = subx.sub_sub_id and
#                      pse_pse_id = ? order by gel_lane", 'ListOfList');
#   $self->{'GetShatterLibraryFromPse'} = LoadSql($self->{'dbh'}, "select subclone_name, clone_name, library_number  from 
#                      clones, clone_growths, clone_growths_libraries, clone_libraries cl, clone_libraries_pses clx, subclones where 
#                      cl_id = clone_growths_libraries.cl_cl_id and cg_id = clone_growths_libraries.cg_cg_id 
#                      and clo_id = clo_clo_id and clx.cl_cl_id = cl_id and 
#                      sub_id = cl.sub_sub_id and
#                      pse_pse_id = ? order by gel_lane", 'ListOfList');

    $self->{'GetProjectFromCloneID'} = LoadSql($dbh, "select distinct pr.project_id, pr.name, cl.clone_name from projects pr,
    clones_projects cp, clones cl 
	where 
	cl.clo_id = cp.clo_clo_id and
	pr.project_id = cp.project_project_id and
	cp.clo_clo_id = ?", 'ListOfList');


   $self->{'GetProjectFromLigationBarcode'} = LoadSql($dbh, "select distinct clone_name
               from 
	       clones clo, clone_growths cg, 
               clone_growths_libraries cgl,
	       clone_libraries cl,  
               fractions fr,
               ligations lg,
               dna_pse lgx,
               pse_barcodes barx, process_step_executions pse where
               clo.clo_id = cg.clo_clo_id and
               cgl.cg_cg_id = cg.cg_id and
               cgl.cl_cl_id = cl.cl_id and
               cl.cl_id = fr.cl_cl_id and
               lg.fra_fra_id = fr.fra_id and
               lgx.dna_id = lg.lig_id and
               pse.pse_id = lgx.pse_id and
               barx.pse_pse_id = pse.pse_id and
               barx.bs_barcode = ? and barx.direction = 'out'", 'Single');

    $self->{'GetLigationVectorType'} = LoadSql($dbh, "select distinct vt_vector_type from vectors, vector_linearizations, ligations, dna_pse, pse_barcodes
                                                    where vec_id = vec_vec_id and vl_id = vl_vl_id and lig_id = dna_id and pse_barcodes.pse_pse_id = 
                                                    dna_pse.pse_id and bs_barcode = ? and direction = ?", 'Single');

    $self -> {'GetAvailSubclones'} = LoadSql($dbh,  "select distinct clone_name,  subclone_name, pse_id from 
               clones cl, clone_growths cg, clone_growths_libraries cgl,
               fractions fra, ligations lig, pse_barcodes barx, 
               process_step_executions pse, subclones sc,
               subclones_pses subx
               where cl.clo_id = cg.clo_clo_id and 
                   cg.cg_id = cgl.cg_cg_id and
                   cgl.cl_cl_id = fra.cl_cl_id and 
                   fra.fra_id = lig.fra_fra_id and 
                   barx.pse_pse_id = pse.pse_id and
                   pse.pse_id = subx.pse_pse_id and 
                   sc.lig_lig_id = lig.lig_id and 
                   sc.sub_id = subx.sub_sub_id and
                   pse.psesta_pse_status = ? and 
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = ?)", 'ListOfList');

    $self -> {'GetNewProjectPse'} = LoadSql($dbh, "select distinct pse_id from process_step_executions, projects_pses
                                                where pse_pse_id = pse_id and ps_ps_id = ? and project_project_id = ?", 'Single');
    

    $self->{'GetAvailLibraryShatter'} = LoadSql($dbh, "select distinct library_number, subclone_name, pse.pse_id
               from 
	       clone_libraries cl,  
               clone_libraries_pses clx, subclones, 
               pse_barcodes barx, process_step_executions pse where
               cl.cl_id = clx.cl_cl_id and
               sub_sub_id = sub_id and 
               pse.pse_id = clx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = (select purpose from process_steps where ps_id = ?))", 'ListOfList');

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
# Destroy a LibSql session #
#############################
sub destroy {
    my ($self) = @_;  
    $self->{'CoreSql'}->destroy;
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

#########################################
# Get avialable growths for inoculation #
#########################################
sub GetAvailClone {

    my ($self, $barcode, $ps_id) = @_;
   
    my $lol = $self->{'GetAvailClone'} -> xSql($barcode, $ps_id);
 
    if(! defined $lol->[0][0]) {
	#locate the right growth

	my $ps = GSC::ProcessStep->get($ps_id);
	my @prior_ps = GSC::ProcessStep->get(process_to => $ps->process);

	my @pb = GSC::PSEBarcode->get(barcode=>$barcode);
	my @pse = GSC::PSE->get(pse_id=>[map {$_->pse_id} @pb],
				ps_id=>[ map {$_->ps_id} @prior_ps],
				pse_status=>'inprogress');
	
	if (@pse) {
	    my @dp = GSC::DNAPSE->get(pse_id=>$pse[0]);
	    if (!@dp) {
		$self->{'Error'} = "$pkg: GetAvailClone() -> Found a PSE inprogress but no dna linked to it for barcode $barcode.";
		return;
	    }
	    
	    my $d = GSC::DNA->get($dp[0]->dna_id);
	    return ($d->dna_name, [$pse[0]->pse_id]);
	} else {
	    $self->{'Error'} = "$pkg: GetAvailClone() -> No valid prior pses inprogress for this barcode $barcode.";
	    return;
	}
    } else {
	return ($lol->[0][0], [$lol->[0][1]]);
    }


    $self->{'Error'} = "$pkg: GetAvailClone() -> Could not find library description information for barcode = $barcode, ps_id = $ps_id.";
    
    return 0;

} #GetAvailClone

######################################################################
# Get growth available where previous step was output and inprogress #
######################################################################
sub GetAvailGrowthOutInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailGrowth($barcode, $ps_id, 'out', 'inprogress');

    return ($result, $pses);
} #GetAvailGrowthOutInprogress

######################################################################
# Get growth available where previous step was input and inprogress  #
######################################################################
sub GetAvailGrowthInInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailGrowth($barcode, $ps_id, 'in', 'inprogress');

    return ($result, $pses);
} #GetAvailGrowthInInprogress
######################################################################
# Get growth available where previous step was input and inprogress  #
######################################################################
sub GetAvailGrowthInCompleted {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailGrowth($barcode, $ps_id, 'in', 'completed');

    return ($result, $pses);
} #GetAvailGrowthInCompleted

################################################
#  main growth available processing subroutine #
################################################
sub GetAvailGrowth {

    my ($self, $barcode, $ps_id, $direction, $status) = @_;

    my $lol = $self->{'GetAvailCloneGrowth'} -> xSql($status, $barcode, $direction, $ps_id, $ps_id);
    
    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1], [$lol->[0][2]]);
    }

    $self->{'Error'} = "$pkg: GetAvailGrowth() -> Could not find clone description information for barcode = $barcode, ps_id = $ps_id, status = $status.";

    return 0;

} #GetAvailGrowth

#######################################
# Get growth available for sonication #
#######################################
sub GetAvailGrowthToSonicate {

    my ($self, $barcode, $ps_id) = @_;
    my $direction = 'in';
    my $status = 'completed';


    my $lol = $self->{'GetAvailCloneGrowthToSonicate'} -> xSql($status, $barcode, $direction, $ps_id, $ps_id, $barcode);
    
    if(defined $lol->[0][0]) {
	my $pre_pse_id = Query($self->{'dbh'}, "select pse_pse_id from pse_barcodes where direction = 'out' and bs_barcode = '$barcode'");
	
	return ($lol->[0][0].' '.$lol->[0][1], [$pre_pse_id]);
    }

    $self->{'Error'} = "$pkg: GetAvailGrowthToSonicate() -> Could not find clone description information for barcode = $barcode, ps_id = $ps_id, status = $status.";
    return 0;

} #GetAvailGrowthToSonicate

sub GetAvailLibraryGelCheck {
    my ($self, $status, $result, $barcode, $direction, $ps_id) = @_;
    my $lol = $self->{'GetAvailLibraryPSEGelCheck'}->xSql($ps_id, $status, $result, $barcode, $direction);
    if(defined $lol->[0][0]) {
      foreach my $pses (@$lol) {
        my $lol1 = $self->{'GetAvailLibraryGelCheckInfo'}->xSql($pses->[0]);
	if(defined $lol1->[0][0]) {
	  return $lol1;
	}
      }
    }
    
    $self->{'Error'} = "$pkg: GetAvailLibraryResonicate() -> Could not find clone description information for barcode = $barcode, ps_id = $ps_id, status = $status.";

    return [];
}

sub GetAvailLibraryResonicate {

    my ($self, $barcode, $ps_id) = @_;
    my $direction = 'out';
    my $status = 'completed';
    my $result = 'unsuccessful';

    
    #my $lol = $self->GetAvailLibraryGelCheck($status, $result, $barcode, $direction, $ps_id, $ps_id);
    my $lol = $self->GetAvailLibraryGelCheck($status, $result, $barcode, $direction, $ps_id);
    
    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1], [$lol->[0][2]]);
    }
    
    $self->{'Error'} = "$pkg: GetAvailLibraryResonicate() -> Could not find clone description information for barcode = $barcode, ps_id = $ps_id, status = $status.";

    return 0;
} #GetAvailLibraryResonicate

sub GetAvailLibraryPassCheckGel {

    my ($self, $barcode, $ps_id) = @_;
    my $direction = 'out';
    my $status = 'completed';
    my $result = 'successful';

    
    #my $lol = $self->GetAvailLibraryGelCheck($status, $result, $barcode, $direction, $ps_id, $ps_id);
    my $lol = $self->GetAvailLibraryGelCheck($status, $result, $barcode, $direction, $ps_id);
    
    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1], [$lol->[0][2]]);
    }
    else {
	
	#$lol = $self->GetAvailLibraryGelCheck($status, $result, $barcode, 'in', $ps_id, $ps_id);
	$lol = $self->GetAvailLibraryGelCheck($status, $result, $barcode, 'in', $ps_id);
	if(defined $lol->[0][0]) {
	    return ($lol->[0][0].' '.$lol->[0][1], [$lol->[0][2]]);
	}
    }
    

    $self->{'Error'} = "$pkg: GetAvailLibraryPassCheckGel() -> Could not find clone description information for barcode = $barcode, ps_id = $ps_id, status = $status.";

    return 0;

} #GetAvailLibraryPassCheckGel


sub GetAvailFractionPassCheckGel {

    my ($self, $barcode, $ps_id) = @_;
    my $direction = 'out';
    my $status = 'completed';
    my $result = 'successful';

    
    my $lol = $self->{'GetAvailFractionGelCheck'} -> xSql($status, $result, $barcode, $direction, $ps_id, $ps_id);
    
    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1].' '.$lol->[0][2], [$lol->[0][3]]);
    }
    
    $self->{'Error'} = "$pkg: GetAvailFractionPassCheckGel() -> Could not find clone description information for barcode = $barcode, ps_id = $ps_id, status = $status.";

    return 0;

} #GetAvailFractionPassCheckGel


sub GetAvailLigationPassCheckGel {

    my ($self, $barcode, $ps_id) = @_;
    my $direction = 'out';
    my $status = 'completed';
    my $result = 'successful';

    
    my $lol = $self->{'GetAvailLigationGelCheck'} -> xSql($status, $result, $barcode, $direction, $ps_id, 'Ligation');
    
    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1].' '.$lol->[0][2].' '.$lol->[0][3], [$lol->[0][4]]);
    }
    else {
	
	my $lol = $self->{'GetAvailLigationGelCheck'} -> xSql($status, $result, $barcode, 'out', $ps_id, 'Transition Non-Barcoded Library Core');
	if(defined $lol->[0][0]) {
	    return ($lol->[0][0].' '.$lol->[0][1].' '.$lol->[0][2].' '.$lol->[0][3], [$lol->[0][4]]);
	}
    }

    $self->{'Error'} = "$pkg: GetAvailLigationPassCheckGel() -> Could not find clone description information for barcode = $barcode, ps_id = $ps_id, status = $status.";

    return 0;

} #GetAvailFractionPassCheckGel


####################################################################
# Get Glycerol plate info for archive growths into a 96 well plate #
####################################################################
sub GetGlycerolPlateInfo {

   my ($self, $barcode, $ps_id) = @_;	
   
   my $NumOfGrowths = $self -> {'CountGrowthsInPlate'} -> xSql($barcode);

   if($NumOfGrowths < 96) {
       return "96 well plate with $NumOfGrowths wells filled";
   }

   $self->{'Error'} = "$pkg: GetGlycerolPlateInfo() -> Could not count number of growths for barcode = $barcode.";
   
   
   return 0;
   

} #GetGlycerolPlateInfo


###############################################################################
# Get the available input final dna archive plates for creating 1:10 dilution #
###############################################################################
sub GetAvailDilutionInput {

   my ($self, $barcode, $ps_id) = @_;	
   
   my $NumOfGrowths = $self -> {'CountGrowthsInPlate'} -> xSql($barcode);

   if($NumOfGrowths > 72) {    
       my $pses = $self -> {'GetPsesForFinalDnaArchivePlate'} -> xSql($barcode);
       
       return ("final dna archive", $pses);
   }

   $self->{'Error'} = "$pkg: GetAvailDilutionInput() -> Number of growths in plate = $NumOfGrowths for barcode = $barcode.  Need >72 to transfer.";
   
   return 0;


} #GetAvailDilutionInput

####################################################
# Verify Growth is available for final dna archive #
####################################################
sub GetAvailGrowthForArchive {

    my ($self, $barcode) = @_;

    if($barcode eq 'empty') {
	return 'empty';
    }
#    my $final_dna_ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Growth Prep', 'isopropanol precipitation 2', 'finalize dna', '1.7mL growth dna tube', 'library core');
#    return ($self->GetCoreError) if(!$final_dna_ps_id);

    my $lib_set_ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Library Construction', 'confirm digest', 'assign to library set', 'none', 'library core');
    return ($self->GetCoreError) if(!$lib_set_ps_id);

    my $lol = $self->{'GetAvailGrowthForArchive'}->xSql('completed',$barcode, 'out', $lib_set_ps_id); 
    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1]);
    }
    
    $self->{'Error'} = "$pkg: GetAvailGrowthForArchive() -> Growth not find growth to archive where barcode = $barcode, ps_id = $lib_set_ps_id.";
    
    return 0;
} #GetAvailGrowthForSonication

########################################################################
# Get library available where previous step was output and inprogress  #
########################################################################
sub GetAvailLibraryOutInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailLibrary($barcode, $ps_id, 'out', 'inprogress');

    return ($result, $pses);
} #GetAvailLibraryInInprogress

#######################################################################
# Get library available where previous step was input and inprogress  #
#######################################################################
sub GetAvailLibraryInInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailLibrary($barcode, $ps_id, 'in', 'inprogress');

    return ($result, $pses);
} #GetAvailLibraryInInprogress

################################################
#  main library available processing subroutine #
################################################
sub GetAvailLibrary {

    my ($self, $barcode, $ps_id, $direction, $status) = @_;

    my $lol = $self->{'GetAvailLibrary'} -> xSql($status, $barcode, $direction, $ps_id, $ps_id);
    
    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1], [$lol->[0][2]]);
    }

    $self->{'Error'} = "$pkg: GetAvailLibrary() -> $barcode, $ps_id, $direction, $status.";

    return 0;

} #GetAvailLibrary


sub GetAvailSonicationToLoad1 {
    my ($self, $barcode) = @_;

    my $result = $self->GetAvailSonicationToLoad($barcode, 1);

    return $result;
}

sub GetAvailSonicationToLoad2 {
    my ($self, $barcode) = @_;

    my $result = $self->GetAvailSonicationToLoad($barcode, 2);

    return $result;
}

sub GetAvailSonicationToLoad3 {
    my ($self, $barcode) = @_;

    my $result = $self->GetAvailSonicationToLoad($barcode, 3);

    return $result;
}



sub GetAvailSonicationToLoad {

    my ($self, $barcode, $gel) = @_;


    if($barcode eq 'empty') {
	return 'Marker';
    }

    my $ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Library Construction', 'sonicate', 'load sonication gel', 'sonication gel '.$gel, 'library core');

    return ($self->GetCoreError) if(!$ps_id);
    
    my ($result, $pses) = $self->GetAvailLibraryOutInprogress($barcode, $ps_id);
    
    if(!$result) {
        ($result, $pses) = $self->GetAvailLibraryInInprogress($barcode, $ps_id);
    }

    return ($result);

} #GetAvailSonicationToLoad


sub GetAvailShatterSonicationToLoad {
    my ($self, $barcode) = @_;
    
    if($barcode eq 'empty') {
	return 'Marker';
    }
    my $ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Shatter', 'sonicate', 'load sonication gel', 'sonication gel', 'library core');
    
    my $lol = $self->{'GetAvailLibraryShatter'} -> xSql('inprogress', $barcode, 'in', $ps_id, $ps_id);
    
    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1]);
    }

    $self->{'Error'} = "$pkg: GetAvailShatterSonicationToLoad() -> $barcode";


    return 0;
}

sub GetAvailLibraryGel {

    my ($self, $barcode, $ps_id) = @_;
    
    my $lol = $self->{'GetAvailLibraryGel'} -> xSql('inprogress', $barcode, 'out', $ps_id, $ps_id);

    if(defined $lol->[0][0]) {
	my $i = 0;
	my @pses;
	foreach my $line (@{$lol}) {
	    push(@pses, $lol->[$i][1]);
	    $i++;
	}
	
	return ('Gel', \@pses);
    }

    $self->{'Error'} = "$pkg: GetAvailLibraryGel() -> $barcode, $ps_id.";

    return 0;

} #GetAvailLibraryGel

sub GetAvailFractionGel {

    my ($self, $barcode, $ps_id) = @_;
    
    my $lol = $self->{'GetAvailFractionGel'} -> xSql('inprogress', $barcode, 'out', $ps_id, $ps_id);

    if(defined $lol->[0][0]) {
	my $i = 0;
	my @pses;
	foreach my $line (@{$lol}) {
	    push(@pses, $lol->[$i][1]);
	    $i++;
	}
	
	return ('Gel', \@pses);
    }

    $self->{'Error'} = "$pkg: GetAvailFractionGel() -> $barcode, $ps_id.";

    return 0;

} #GetAvailFractionGel

sub GetAvailLigationGel {

    my ($self, $barcode, $ps_id) = @_;
    
    my $lol = $self->{'GetAvailLigationGel'} -> xSql('inprogress', $barcode, 'out', $ps_id, $ps_id);

    if(defined $lol->[0][0]) {
	my $i = 0;
	my @pses;
	foreach my $line (@{$lol}) {
	    push(@pses, $lol->[$i][1]);
	    $i++;
	}
	
	return ('Gel', \@pses);
    }

    $self->{'Error'} = "$pkg: GetAvailLigationGel() -> $barcode, $ps_id.";

    return 0;
} #GetAvailLigatioGel


sub GetAvailSubcloneGel {

    my ($self, $barcode, $ps_id) = @_;
    
    my $lol = $self->{'GetAvailSubcloneGel'} -> xSql('inprogress', $barcode, 'out', $ps_id, $ps_id);

    if(defined $lol->[0][0]) {
	my $i = 0;
	my @pses;
	foreach my $line (@{$lol}) {
	    push(@pses, $lol->[$i][1]);
	    $i++;
	}
	
	return ('Gel', \@pses);
    }

    $self->{'Error'} = "$pkg: GetAvailSubcloneGel() -> $barcode, $ps_id.";

    return 0;
} #GetAvailSubcloneGel

sub GetLibraryOnGel {

    my ($self, $barcode, $pse_id) = @_;
    
    my $lol = $self->{'GetLibraryOnGel'} -> xSql($pse_id);
    
    if(defined $lol->[0][0]) {
	return($lol->[0][0]."\t".$lol->[0][1].' '.$lol->[0][2].' '.$lol->[0][3]);
    }
    
    $self->{'Error'} = "$pkg: GetLibraryOnGel() -> $pse_id.";

    return 0;
} #GetLibraryOnGel

sub GetFractionOnGel {

    my ($self, $barcode, $pse_id) = @_;
    
    my $lol = $self->{'GetFractionOnGel'} -> xSql($pse_id);
    
    if(defined $lol->[0][0]) {
	return($lol->[0][0]."\t".$lol->[0][1].' '.$lol->[0][2].' '.$lol->[0][3].' '.$lol->[0][4]);
    }
    
    $self->{'Error'} = "$pkg: GetFractionOnGel() -> $pse_id.";

    return 0;
} #GetFractionOnGel


sub GetLigationOnGel {

    my ($self, $barcode, $pse_id) = @_;
    
    my $lol = $self->{'GetLigationOnGel'} -> xSql($pse_id);
    
    if(defined $lol->[0][0]) {
	return($lol->[0][0]."\t".$lol->[0][1].' '.$lol->[0][2].' '.$lol->[0][3].' '.$lol->[0][4]);
    }
    
    $self->{'Error'} = "$pkg: GetLigationOnGel() -> $pse_id.";

    return 0;
} #GetLigationOnGel

sub GetSubcloneOnGel {

    my ($self, $barcode, $pse_id) = @_;
    
    my $lol = $self->{'GetSubcloneOnGel'} -> xSql($pse_id);
    
    if(defined $lol->[0][0]) {
	return($lol->[0][0]."\t".$lol->[0][1].' '.$lol->[0][2]);
    }
    
    $self->{'Error'} = "$pkg: GetSubcloneOnGel() -> $pse_id.";

    return 0;
} #GetSubcloneOnGel

sub GetAvailLibraryToLoadFractionGel {

    my ($self, $barcode) = @_;

    my $ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Library Construction', 'mung phenol extraction', 'load fraction gel', 'fraction gel', 'library core');
    return ($self->GetCoreError) if(!$ps_id);
    
    my ($result, $pses) = $self->GetAvailLibraryOutInprogress($barcode, $ps_id);
    
    if(!$result) {
        ($result, $pses) = $self->GetAvailLibraryInInprogress($barcode, $ps_id);
    }

    return ($result);

} #GetAvailLibraryToLoadFractionGel

sub GetAvailLibraryToLoadShatterFractionGel {

    my ($self, $barcode) = @_;

    my $ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Shatter', 'mung phenol extraction', 'load fraction gel', 'fraction gel', 'library core');
    return ($self->GetCoreError) if(!$ps_id);
    
    my ($result, $pses) = $self->GetAvailLibraryOutInprogress($barcode, $ps_id);

    return ($result);

} #GetAvailLibraryToLoadFractionGel


########################################################################
# Get fraction available where previous step was output and inprogress  #
########################################################################
sub GetAvailFractionToLigate {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailFraction($barcode, $ps_id, 'out', 'inprogress');
    
    if(!$result) {
        ($result, $pses) = $self -> GetAvailFraction($barcode, $ps_id, 'in', 'inprogress');
    }

    return ($result, $pses);
} #GetAvailFractionToLigate


########################################################################
# Get fraction available where previous step was output and inprogress  #
########################################################################
sub GetAvailFractionOutInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailFraction($barcode, $ps_id, 'out', 'inprogress');

    return ($result, $pses);
} #GetAvailFractionInInprogress

#######################################################################
# Get fraction available where previous step was input and inprogress  #
#######################################################################
sub GetAvailFractionInInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailFraction($barcode, $ps_id, 'in', 'inprogress');

    return ($result, $pses);
} #GetAvailFractionInInprogress

################################################
#  main fraction available processing subroutine #
################################################
sub GetAvailFraction {

    my ($self, $barcode, $ps_id, $direction, $status) = @_;

    my $lol = $self->{'GetAvailFraction'} -> xSql($status, $barcode, $direction, $ps_id);
    
    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1].' '.$lol->[0][2], [$lol->[0][3]]);
    }

    $self->{'Error'} = "$pkg: GetAvailFraction() -> $barcode, $ps_id, $direction, $status.";

    return 0;

} #GetAvailFraction

sub GetAvailFractionToLoad1 {
    my ($self, $barcode) = @_;

    my $result = $self->GetAvailFractionToLoad($barcode, 1);

    return $result;
}

sub GetAvailFractionToLoad2 {
    my ($self, $barcode) = @_;

    my $result = $self->GetAvailFractionToLoad($barcode, 2);

    return $result;
}

sub GetAvailFractionToLoad3 {
    my ($self, $barcode) = @_;

    my $result = $self->GetAvailFractionToLoad($barcode, 3);

    return $result;
}



sub GetAvailFractionToLoad {

    my ($self, $barcode, $gel) = @_;


    if($barcode eq 'empty') {
	return 'Marker';
    }

    my $ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Library Construction', 'fraction phenol extraction 2', 'load fraction quantitation gel', 'fraction quantitation gel '.$gel, 'library core');
    return ($self->GetCoreError) if(!$ps_id);
    
    my ($result, $pses) = $self->GetAvailFractionOutInprogress($barcode, $ps_id);
    
    if(!$result) {
        ($result, $pses) = $self->GetAvailFractionInInprogress($barcode, $ps_id);
    }

    return ($result);

} #GetAvailFractionToLoad


sub GetAvailFractionToDryDown {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailFraction($barcode, $ps_id, 'out', 'inprogress');
   

    if($result) {
	
	my $count = Query($self->{'dbh'}, "select count(*)
               from 
               fractions_pses frx, process_steps ps,
               process_step_executions pse where
               pse.pse_id = frx.pse_pse_id and
               ps_id = ps_ps_id and 
               pse.psesta_pse_status = 'completed' and
               purpose = 'Restriction Digest Subcloning' and pro_process_to = 'create fraction dilution' and
               frx.fra_fra_id in (select fra_fra_id from fractions_pses where pse_pse_id in 
                                  (select pse_pse_id from pse_barcodes where bs_barcode = '$barcode' and direction = 'in'))", 'ListOfList');

	if($count == 1) {
	    return ($result, $pses);
	}
	else {
	    $self->{'Error'} = "$pkg: GetAvailFractionToDryDown() -> Fraction Dilution has not been created.";
	}
    }

    return 0;
} #GetAvailFractionToDryDown

sub GetAvailLigationToLoad1 {
    my ($self, $barcode) = @_;

    my $result = $self->GetAvailLigationToLoad($barcode, 1);

    return $result;
}

sub GetAvailLigationToLoad2 {
    my ($self, $barcode) = @_;

    my $result = $self->GetAvailLigationToLoad($barcode, 2);

    return $result;
}

sub GetAvailLigationToLoad3 {
    my ($self, $barcode) = @_;

    my $result = $self->GetAvailLigationToLoad($barcode, 3);

    return $result;
}



sub GetAvailLigationToLoad {

    my ($self, $barcode, $gel) = @_;


    if($barcode eq 'empty') {
	return 'Marker';
    }

    my $ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Ligation', 'dilute ligation', 'load dilution gel', 'dilution gel '.$gel, 'library core');
    return ($self->GetCoreError) if(!$ps_id);
    
    my ($result, $pses) = $self->GetAvailLigationOutInprogress($barcode, $ps_id);
    
    if(!$result) {
        ($result, $pses) = $self->GetAvailLigationInInprogress($barcode, $ps_id);
    }

    return ($result);

} #GetAvailLigationToLoad

sub GetAvailLigatedFraction {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailLigation($barcode, $ps_id, 'in', 'inprogress');
    
    if(!$result) {
	# check if barcode is old stuff
	($result, $pses) = $self -> GetAvailLigation($barcode, $ps_id, 'out', 'inprogress');
    }

    return ($result, $pses);

} #GetAvailLigatedFraction


########################################################################
# Get ligation available where previous step was output and inprogress  #
########################################################################
sub GetAvailLigationOutInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailLigation($barcode, $ps_id, 'out', 'inprogress');

    return ($result, $pses);
} #GetAvailLigationOutInprogress

########################################################################
# Get ligation available where previous step was output and inprogress  #
########################################################################
sub GetAvailLigationOutCompleted {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailLigation($barcode, $ps_id, 'out', 'completed');

    return ($result, $pses);
} #GetAvailLigationInInprogress

#######################################################################
# Get ligation available where previous step was input and inprogress  #
#######################################################################
sub GetAvailLigationInInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailLigation($barcode, $ps_id, 'in', 'inprogress');

    return ($result, $pses);
} #GetAvailLigationInInprogress

#######################################################################
# Get ligation available where previous step was input and inprogress  #
#######################################################################
sub GetAvailLigationInCompleted {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailLigation($barcode, $ps_id, 'in', 'completed');

    return ($result, $pses);
} #GetAvailLigationInCompleted

################################################
#  main ligation available processing subroutine #
################################################
sub GetAvailLigation {

    my ($self, $barcode, $ps_id, $direction, $status) = @_;

    my $lol = $self->{'GetAvailLigation'} -> xSql($status, $barcode, $direction, $ps_id, $ps_id);
    
    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1], [$lol->[0][2]]);
    }

    $self->{'Error'} = "$pkg: GetAvailLigation() -> $barcode, $ps_id, $direction, $status.";

    return 0;

} #GetAvailLigation


########################################################################
# Get ligation available where previous step was output and inprogress  #
########################################################################
sub GetAvailDilutionToConfirm {

    my ($self, $barcode, $ps_id) = @_;

    my $direction = 'out';
    my $status = 'inprogress';
    my $schema = $self->{'Schema'};
    my $dbh = $self->{'dbh'};
    $self->{'GetLigationVectorType'} = LoadSql($dbh, "select distinct vt_vector_type from vectors, vector_linearizations, ligations, dna_pse, pse_barcodes
                                                    where vec_id = vec_vec_id and vl_id = vl_vl_id and lig_id = lig_lig_id and pse_barcodes.pse_pse_id = 
                                                    dna_pse.pse_id and bs_barcode = ? and direction = ?", 'Single');


    my $vector_type = $self->{'GetLigationVectorType'} -> xSql($barcode, 'out');
    
    if($vector_type eq 'filamentous phage') {
	my ($result, $pses) = $self -> GetAvailM13Dilutions($barcode, $ps_id, $status, $direction);
	if(!$result) {
	    ($result, $pses) = $self -> GetAvailM13Dilutions($barcode, $ps_id, 'completed', $direction);
	}
	return ($result, $pses);
    }
    else {
	my ($result, $pses) = $self -> GetAvailPlasmidDilutions($barcode, $ps_id, $status, $direction);
	if(!$result) {
	    ($result, $pses) = $self -> GetAvailPlasmidDilutions($barcode, $ps_id, 'completed', $direction);
	}
	return ($result, $pses);
    }
    
    $self->{'Error'} = "$pkg: GetAvailDilutionToRetire() Could not find vector type.";
    return (0);

} #GetAvailDilutionToConfirm

########################################################################
# Get ligation available where previous step was output and inprogress  #
########################################################################
sub GetAvailDilutionToRetire {

    my ($self, $barcode, $ps_id) = @_;

    my $direction = 'in';
    my $status = 'completed';
    my $schema = $self->{'Schema'};
    my $dbh = $self->{'dbh'};
    my $vector_type = $self->{'GetLigationVectorType'} -> xSql($barcode, 'out');
    
    if($vector_type eq 'filamentous phage') {
	my ($result, $pses) = $self -> GetAvailM13Dilutions($barcode, $ps_id, $status, $direction);
	return ($result, $pses);
    }
    else {
      my $retire_ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Ligation', 'confirm dilution', 'retire dilution', 'none', 'library core');
      return ($self->GetCoreError) if(!$retire_ps_id);
      $self->{'CheckIfDilutionRetired'} = LoadSql($dbh, "select count(*) from process_step_executions, pse_barcodes where 
                                                             pse_id = pse_pse_id and bs_barcode = ? and direction = 'in' and ps_ps_id = ?", 'Single');

      my $retired = $self->{'CheckIfDilutionRetired'} -> xSql($barcode, $retire_ps_id);

      if(!$retired) {
        my ($result, $pses) = $self->{'CoreSql'}->GetAvailBarcode($barcode, $direction, $ps_id, 'inprogress', 'completed');
	return ($result, $pses);
      } else {
	$self->{'Error'} = "$pkg: GetAvailDilutionToRetire() $barcode already retired!";
        return (0);      
      }
    }
    
    $self->{'Error'} = "$pkg: GetAvailDilutionToRetire() Could not find vector type.";
    return (0);

} #GetAvailDilutionToRetire

########################################################################
# Get ligation available where previous step was output and inprogress  #
########################################################################
sub GetAvailLigationToRetire {

    my ($self, $barcode, $ps_id) = @_;
    
    my $direction = 'in';
    my $status = 'completed';
    my $schema = $self->{'Schema'};
    my $dbh = $self->{'dbh'};
    $self->{'GetLigationVectorType'} = LoadSql($dbh, "select distinct vt_vector_type from vectors, vector_linearizations, ligations, dna_pse, pse_barcodes
                                                    where vec_id = vec_vec_id and vl_id = vl_vl_id and lig_id = lig_lig_id and pse_barcodes.pse_pse_id = 
                                                    dna_pse.pse_id and bs_barcode = ? and direction = ?", 'Single');

    my $vector_type = $self->{'GetLigationVectorType'} -> xSql($barcode, 'in');
    
    if($vector_type eq 'plasmid') {
	$self->{'Error'} = "$pkg: GetAvailLigationToRetire() Can not retire plasmid ligations.";
	return (0);
    }
    elsif($vector_type eq 'filamentous phage') {
	my ($result, $pses) = $self -> GetAvailM13Dilutions($barcode, $ps_id, $status, $direction);
	return ($result, $pses);
    }

    $self->{'Error'} = "$pkg: GetAvailLigationToRetire() Could not find vector type.";
    return (0);
} #GetAvailLigationToRetire

###################################
# Get available dilution to claim #
###################################
sub GetAvailM13DilutionsToClaim {

    my ($self, $barcode, $ps_id) = @_;

    my $direction = 'in';
    my $purpose = Query($self->{'dbh'}, "select purpose from process_steps where ps_id in (select ps_ps_id from process_step_executions where
                                                 pse_id in (select pse_pse_id from pse_barcodes where direction = 'out' and bs_barcode = '$barcode'))");
    if($purpose eq 'WGS Library Construction') {
	$direction = 'out';
    }
    my ($result, $pses) = $self -> GetAvailM13Dilutions($barcode, $ps_id, 'inprogress', $direction);

    return ($result, $pses);
} #GetAvailM13DilutionsToClaim


################################################
#  get available m13 dilutions                 #
################################################
sub GetAvailM13Dilutions {

    my ($self, $barcode, $ps_id, $status, $direction) = @_;
    
    my $retire_ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Ligation', 'confirm dilution', 'retire dilution', 'none', 'library core');
    return ($self->GetCoreError) if(!$retire_ps_id);

    my $schema = $self->{'Schema'};
    my $dbh = $self->{'dbh'};

    $self->{'CheckIfDilutionRetired'} = LoadSql($dbh, "select count(*) from process_step_executions, pse_barcodes where 
                                                           pse_id = pse_pse_id and bs_barcode = ? and direction = 'in' and ps_ps_id = ?", 'Single');

    my $retired = $self->{'CheckIfDilutionRetired'} -> xSql($barcode, $retire_ps_id);

    if(!$retired) {
	my $lol = $self->{'GetAvailLigationType'} -> xSql($status, $barcode, $direction, 'filamentous phage', $ps_id);
	if(defined $lol->[0][0]) {
	    return ($lol->[0][0].' '.$lol->[0][1], [$lol->[0][2]]);
	}
	
	$self->{'Error'} = "$pkg: GetAvailM13Dilutions() -> $barcode, $ps_id, $direction, $status.";
    }
    else {
	$self->{'Error'} = "$pkg: GetAvailM13Dilutions() The Dilution has been retired.";
    }

    return 0;

} #GetAvailM13Dilutions


###################################
# Get available dilution to claim #
###################################
sub GetAvailPlasmidDilutionsToClaim {

    my ($self, $barcode, $ps_id) = @_;
    my $direction = 'in';
    my $purpose = Query($self->{'dbh'}, "select purpose from process_steps where ps_id in (select ps_ps_id from process_step_executions where
                                                 pse_id in (select pse_pse_id from pse_barcodes where direction = 'out' and bs_barcode = '$barcode'))");
    if(($purpose eq 'WGS Library Construction') || ($purpose eq 'Transition Non-Barcoded Library Core WGS') || ($purpose eq 'Funded Project Management')) {
      $direction = 'out';
    }
    my ($result, $pses) = $self -> GetAvailPlasmidDilutions($barcode, $ps_id, 'inprogress', $direction);
    if($result) {
      return ($result, $pses);
    } else {
      ($result, $pses) = $self -> GetAvailPlasmidDilutions($barcode, $ps_id, 'completed', $direction);
      return ($result, $pses) if($result);
    }
    ($result, $pses) = $self->{'CoreSql'}->GetAvailBarcodeInOutInprogress($barcode, $ps_id);
    return ($result, $pses);
} #GetAvailPlasmidDilutionsToClaim

################################################
#  get available plasmid dilutions             #
################################################
sub GetAvailPlasmidDilutions {

    my ($self, $barcode, $ps_id, $status, $direction) = @_;

    my $retire_ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Ligation', 'confirm dilution', 'retire dilution', 'none', 'library core');
    return ($self->GetCoreError) if(!$retire_ps_id);


    my $schema = $self->{'Schema'};
    my $dbh = $self->{'dbh'};

    $self->{'CheckIfDilutionRetired'} = LoadSql($dbh, "select count(*) from process_step_executions, pse_barcodes where 
                                                           pse_id = pse_pse_id and bs_barcode = ? and direction = 'in' and ps_ps_id = ?", 'Single');

    my $retired = $self->{'CheckIfDilutionRetired'} -> xSql($barcode, $retire_ps_id);

    if(!$retired) {

        my ($result, $pses) = $self->{'CoreSql'}->GetAvailBarcode($barcode, $direction, $ps_id, $status);
        return ($result, $pses) if($result);
#	my $lol = $self->{'GetAvailLigationType'} -> xSql($status, $barcode, $direction, '%mid', $ps_id);
#	
#	if(defined $lol->[0][0]) {
#	    return ($lol->[0][0].' '.$lol->[0][1], [$lol->[0][2]]);
#	}
	
	$self->{'Error'} = "$pkg: GetAvailPlasmidDilutions() -> $barcode, $ps_id, $direction, $status.";
	
    }
    else {
	$self->{'Error'} = "$pkg: GetAvailPlasmidDilutions() The Dilution has been retired.";
    }

    return 0;

} #GetAvailPlamsidDilutions




################################################
#  get available ligations to claim             #
################################################
sub GetAvailLigationToClaim {

    my ($self, $barcode, $ps_id) = @_;
    my $direction = 'in';
    my $status = 'completed';
    my $schema = $self->{'Schema'};
    my $dbh = $self->{'dbh'};

    
    my $retire_ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Ligation', 'ligate fraction', 'retire ligation', 'none', 'library core');
    return ($self->GetCoreError) if(!$retire_ps_id);

    $self->{'CheckIfDilutionRetired'} = LoadSql($dbh, "select count(*) from process_step_executions, pse_barcodes where 
                                                           pse_id = pse_pse_id and bs_barcode = ? and direction = 'in' and ps_ps_id = ?", 'Single');

    my $retired = $self->{'CheckIfDilutionRetired'} -> xSql($barcode, $retire_ps_id);

    if(!$retired) {
	my $lol = $self->{'GetAvailLigationToClaim'} -> xSql($status, $barcode, $direction, $ps_id);
	
	if(defined $lol->[0][0]) {
	    return ($lol->[0][0].' '.$lol->[0][1], [$lol->[0][2]]);
	}
	
	$self->{'Error'} = "$pkg: GetAvailLigationToClaim() -> $barcode, $ps_id, $direction, $status.";

    }
    else {
	$self->{'Error'} = "$pkg: GetAvailLigationToClaim() The Ligation has been retired.";
    }

    return 0;

} #GetAvailPlamsidDilutions

#####################################
# Get avail agar plates for failing #
#####################################
sub GetAvailFailAgarPlate {
    
    my ($self, $barcode, $ps_id) = @_;


    my $lol = $self -> {'GetAvailAgarPlateToFail'} -> xSql('inprogress', $barcode, 'in', 'Plasmid Picking');

    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1], [$lol->[0][2]]);

    }
    else {
	$lol = $self -> {'GetAvailAgarPlateToFail'} -> xSql('inprogress', $barcode, 'out', 'Plasmid Plating');
	if(defined $lol->[0][0]) {
	    return ($lol->[0][0].' '.$lol->[0][1], [$lol->[0][2]]);
	}
    }
    
    $self->{'Error'} = "$pkg: GetAvailFailAgarPlate() -> Could not find agar plate to fail.";

    return 0;

} #GetAvailFailAgarPlate

##########################################
#  main agar plate processing subroutine #
##########################################
sub GetAvailPlasmidAgarPlateOut {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'out', 'inprogress', 'Plasmid Plating');

    return ($result, $pses);

} #GetAvailAgarPlateOut
#  main agar plate processing subroutine #
##########################################
sub GetAvailAgarPlate {

    my ($self, $barcode, $ps_id, $direction, $status, $purpose) = @_;

    my $lol = $self->{'GetAvailAgarPlate'} -> xSql($status, $barcode, $direction, $ps_id, $purpose);
    
    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1], [$lol->[0][2]]);
    }

    $self->{'Error'} = "$pkg: GetAvailAgarPlate() -> $barcode, $ps_id, $direction, $status.";
    $self->{'Error'} = $self->{'Error'}." $DBI::errstr" if(defined $DBI::errstr);

    return 0;

} #GetAvailAgarPlate

##########################################################
##########################################################
sub GetAvailSubclonesToSonicate {

    my ($self, $barcode, $ps_id) = @_;

    						
    my $lol = $self -> {'GetAvailSubclones'} ->xSql('inprogress', $barcode, 'out', $ps_id, 'Shatter');
    
    if(defined $lol->[0][0]) {
	my $desc = $lol->[0][0].' '.$lol->[0][1];
	return ($desc, [$lol->[0][2]]);
    }
	
    $self->{'Error'} = "$pkg: GetAvailSubclones() -> Could not find barcode description information for barcode = $barcode, ps_id = $ps_id.";
    
    
    return (0);

} #

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


####################################
# Get available growths to archive #
####################################
sub GetAvailGlycerol {
    my ($self, $barcode) = @_;

    if($barcode eq 'empty') {
	return 'empty';
    }

    my $status = 'inprogress';
    my $direction = 'out';
    
    my $ps_id = $self -> {'CoreSql'} -> Process('GetPsId', 'Growth Prep', 'transfer growth', 'create glycerol stock', '96 well flat plate', 'library core');
    return ($self->GetCoreError) if(!$ps_id);

    my $lol = $self -> {'GetAvailCloneGrowth'} -> xSql($status, $barcode, $direction, $ps_id, $ps_id);
    
    if(! defined $lol->[0][0]) {

	my $ps_id = $self -> {'CoreSql'} -> Process('GetPsId', 'Short Growth Prep', 'transfer growth', 'create glycerol stock', '96 well flat plate', 'library core');
	return ($self->GetCoreError) if(!$ps_id);
	
	$lol = $self -> {'GetAvailCloneGrowth'} -> xSql($status, $barcode, $direction, $ps_id, $ps_id);
	
    }

    if(defined $lol->[0][0]) {
	return $lol->[0][0].' '.$lol->[0][1];
    }
    

    $self->{'Error'} = "$pkg: GetAvailGlycerol() -> Could not find library description information for barcode = $barcode, ps_id = $ps_id, status = $status.";
    
    return 0;

} #GetAvailGlycerol



####################################
# Get available growths to archive #
####################################
sub GetAvailDNAResouceItem {
    my ($self, $barcode) = @_;

    if($barcode eq 'empty') {
	return 'empty';
    }

    my $status = 'inprogress';
    my $direction = 'out';
    
    my $ps_id = $self -> {'CoreSql'} -> Process('GetPsId', 'Clone Receiving', 'claim dna', 'make glycerol stock', 'corning tray', 'mapping');
    return ($self->GetCoreError) if(!$ps_id);

    my ($desc, $pses) = $self -> {'CoreSql'} -> GetAvailBarcodeInInprogress($barcode, $ps_id);
    
    if(defined $desc) {
	return $desc;
    }
    

    $self->{'Error'} = "$pkg: GetAvailGlycerol() -> Could not find a dna resource description information for barcode = $barcode, ps_id = $ps_id, status = $status.";
    
    return 0;

} #GetAvailGlycerol







##########################################################
# Get available subclones to load on a concentration gel #
##########################################################
sub GetAvailConcentrationsToLoad {

    my ($self, $barcode) = @_;

     if($barcode eq 'empty') {
	return 'Marker';
    }

    my $ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Mini Prep', 'elution', 'load concentration gel', 'dna concentration gel', 'library core');
    return ($self->GetCoreError) if(!$ps_id);
    						
    my $lol = $self -> {'GetAvailSubclones'} ->xSql('inprogress', $barcode, 'out', $ps_id, 'Mini Prep');
    
    if(defined $lol->[0][0]) {
	my $desc = $lol->[0][0].' '.$lol->[0][1];
	return ($desc);
    }
	
    $self->{'Error'} = "$pkg: GetAvailConcentrationsToLoad() -> Could not find barcode description information for barcode = $barcode, ps_id = $ps_id.";
    
    
    return (0);

} #GetAvailConcentrationsToLoad






############################################################################################
#                                                                                          #
#                         Confirm Subrotine Processes                                      #
#                                                                                          #
############################################################################################

#######################
# Create a new growth #
#######################
sub NewGrowth {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';

    #my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
    my $dl_id = $self->getTubeLocation;

    foreach my $bar_out (@{$bars_out}) {
	
	my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_ids->[0], $update_status, $update_result, $bars_in->[0], [$bar_out], $emp_id);
	return ($self->GetCoreError) if(!$new_pse_id);
	
	my ($clo_id, $old_cg_id) = $self->GetCloneIdForNewGrowth($pre_pse_ids->[0]);
	return 0 if((!$clo_id) && (!defined $old_cg_id));

	my $growth_ext = $self->GetNextGrowthExtForClone($clo_id);
	return 0 if(!$growth_ext);
	
	my $cg_id = $self->GetNextCgId;
	return 0 if(!$cg_id);
	
	my $result = $self->InsertCloneGrowths($cg_id, $growth_ext, $clo_id, 'unknown', $old_cg_id, 'production', $new_pse_id, $dl_id);
	return 0 if(!$result);
	
#	$result = $self ->{'CoreSql'}-> InsertDNAPSE($cg_id, $new_pse_id, $dl_id);
#	return 0 if(!$result);
	
	$result = App::DB->sync_database();
	if(!$result) {
	    $self -> {'Error'} = "Failed trying to sync\n";
	    return 0;
	}


	push(@{$pse_ids}, $new_pse_id);
    }

    return $pse_ids;
    
} #NewGrowth

sub getTubeLocation {
    my $self = shift;
    my @dl_ids = map { $_->dl_id } GSC::DNALocation->get(location_type => 'tube', location_name => '0');
    my $dl_id = @dl_ids == 1 ? $dl_ids[0] : undef;
    return $dl_id;
}

#########################
# Process a growth step #
#########################
sub ProcessGrowth {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    my $update_status = 'completed';
    my $update_result = 'successful';
    #my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
    my $dl_id = $self->getTubeLocation;
    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    return ($self->GetCoreError) if(!$new_pse_id);

    my $cg_id = $self -> GetCgIdFromPse($pre_pse_id);
    return 0 if($cg_id == 0);
    
    my $result = $self->{'CoreSql'} -> InsertDNAPSE($cg_id, $new_pse_id,$dl_id);
    return 0 if($result == 0);

    push(@{$pse_ids}, $new_pse_id);
    return $pse_ids;
} #ProcessGrowth


sub ProcessAndFinalizeGrowth {
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    my $update_status = 'completed';
    my $update_result = 'successful';
    #my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
    my $dl_id = $self->getTubeLocation;
    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    return ($self->GetCoreError) if(!$new_pse_id);

    my $cg_id = $self -> GetCgIdFromPse($pre_pse_id);
    return 0 if($cg_id == 0);
    
    my $result = $self->{'CoreSql'} -> InsertDNAPSE($cg_id, $new_pse_id,$dl_id);
    return 0 if($result == 0);

    push(@{$pse_ids}, $new_pse_id);

    foreach my $pse_id (@{$pse_ids}) {
	
	my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pse_id);
	return ($self->GetCoreError) if(!$result);
	
	$result = $self -> PrintCloneLabel($pse_id);
	return 0 if($result == 0);
    }


    return $pse_ids;
}


###########################################################
# Create a glycerol archive of growths in a 96 well plate #
###########################################################
sub CreateGlycerolGrowth {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = [];
    my $count = 0;
    my $event_pse_id;
    
    my $purpose = Query($self->{'dbh'}, qq/select purpose from process_steps where ps_id = $ps_id/);

    my $avail_plate_locs =  $self -> GetAvailableLocationsInGrowthPlate($bars_in->[0]);
    return 0 if(!$avail_plate_locs);

    foreach my $growth_bar (@{$bars_out}) {
	if(!($growth_bar =~ /^empty/)) {
	    my $pre_bar_dir = 'out';
	    my $pre_pse_status = 'inprogress';
	    my $update_status = 'completed';
	    my $update_result = 'successful';
	    
	    $pre_pse_ids = $self->{'CoreSql'}->Process('GetPrePseForBarcode', $growth_bar, $pre_bar_dir, $pre_pse_status, $ps_id);
	    return ($self->GetCoreError) if(!$pre_pse_ids->[0]);
	    
	    my $pre_pse_id = $pre_pse_ids->[0];
	    
	    my $result =  $self->{'CoreSql'}->Process('UpdatePse', $update_status, $update_result, $pre_pse_id);
	    return ($self->GetCoreError) if(!$result);
	    
	    if(($count==0) || (! defined $event_pse_id)) {

		$event_pse_id =  $self->{'CoreSql'}->Process('GetNextPse');
		return ($self->GetCoreError) if(!$event_pse_id);
		
		#PSE_SESSION,PSESTA_PSE_STATUS, PR_PSE_RESULT, PS_PS_ID, EI_EI_ID, PSE_ID, EI_EI_ID_CONFIRM, PIPE
		$result = $self->{'CoreSql'}->Process('InsertPseEvent', '0','completed', 'successful', $ps_id, $emp_id, $event_pse_id, $emp_id, 0, $pre_pse_id);
		return ($self->GetCoreError) if(!$result);
		
		#bs_barcode, pse_pse_id, direction
		$result = $self->{'CoreSql'}->Process('InsertBarcodeEvent', $bars_in->[0], $event_pse_id, 'out');
		return ($self->GetCoreError) if(!$result);
	    }    
	    
	    $result = $self->{'CoreSql'}->Process('InsertBarcodeEvent', $growth_bar, $event_pse_id, 'in');
	    return ($self->GetCoreError) if(!$result);
	    
	    my $cg_id = $self -> GetCgIdFromPse($pre_pse_id);
	    return 0 if($cg_id == 0);
	    
	    $result = $self ->{'CoreSql'}-> InsertDNAPSE($cg_id, $event_pse_id, $avail_plate_locs->[$count]);
	    return 0 if($result == 0);
	    

	    push(@{$pse_ids}, $event_pse_id);


	    # Insert next step
	    my $pellet_ps_id;

	    if($purpose eq 'Growth Prep') {
		$pellet_ps_id= $self-> {'CoreSql'} -> Process('GetPsId', 'Growth Prep', 'transfer growth', 'pellet cells', '250mL centrifuge bottle', 'library core');
	    }
	    elsif($purpose eq 'Short Growth Prep')  {
		$pellet_ps_id= $self-> {'CoreSql'} -> Process('GetPsId', 'Short Growth Prep', 'transfer growth', 'pellet cells', '250mL centrifuge bottle', 'library core');
	    }
            else {
                next;
            }
	    return ($self->GetCoreError) if(!$pellet_ps_id);
	    
	    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($pellet_ps_id, $pre_pse_id, $update_status, $update_result, $growth_bar, undef, $emp_id);
	    return ($self->GetCoreError) if(!$new_pse_id);
	    
	    #my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
            my $dl_id = $self->getTubeLocation;

	    $result = $self ->{'CoreSql'}-> InsertDNAPSE($cg_id, $new_pse_id, $dl_id);
	    return 0 if($result == 0);

	}
	$count++;
    }


    return $pse_ids;
} #CreateGlycerolGrowth

###########################################################
# Create a glycerol archive of growths in a 96 well plate #
###########################################################
sub CreateGlycerolMapping {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = [];
    my $count = 0;
    my $event_pse_id;
    
    my $purpose = Query($self->{'dbh'}, qq/select purpose from process_steps where ps_id = $ps_id/);

    my $avail_plate_locs =  $self -> GetAvailableLocationsInGrowthPlate($bars_in->[0]);
    return 0 if(!$avail_plate_locs);

    foreach my $growth_bar (@{$bars_out}) {
	if(!($growth_bar =~ /^empty/)) {
	    my $pre_bar_dir = 'out';
	    my $pre_pse_status = 'inprogress';
	    my $update_status = 'completed';
	    my $update_result = 'successful';

            my ($desc, $pre_pse_ids) = $self -> {'CoreSql'} -> GetAvailBarcodeInInprogress($growth_bar, $ps_id);
  
	    #$pre_pse_ids = $self->{'CoreSql'}->Process('GetPrePseForBarcode', $growth_bar, $pre_bar_dir, $pre_pse_status, $ps_id);
	    #return ($self->GetCoreError) if(!$pre_pse_ids->[0]);
	    
	    my $pre_pse_id = $pre_pse_ids->[0];
	    
	    my $result =  $self->{'CoreSql'}->Process('UpdatePse', $update_status, $update_result, $pre_pse_id);
	    return ($self->GetCoreError) if(!$result);
	    
	    if(($count==0) || (! defined $event_pse_id)) {

		$event_pse_id =  $self->{'CoreSql'}->Process('GetNextPse');
		return ($self->GetCoreError) if(!$event_pse_id);
		
		#PSE_SESSION,PSESTA_PSE_STATUS, PR_PSE_RESULT, PS_PS_ID, EI_EI_ID, PSE_ID, EI_EI_ID_CONFIRM, PIPE
		$result = $self->{'CoreSql'}->Process('InsertPseEvent', '0','completed', 'successful', $ps_id, $emp_id, $event_pse_id, $emp_id, 0, $pre_pse_id);
		return ($self->GetCoreError) if(!$result);
		
		#bs_barcode, pse_pse_id, direction
		$result = $self->{'CoreSql'}->Process('InsertBarcodeEvent', $bars_in->[0], $event_pse_id, 'out');
		return ($self->GetCoreError) if(!$result);
	    }    
	    
	    $result = $self->{'CoreSql'}->Process('InsertBarcodeEvent', $growth_bar, $event_pse_id, 'in');
	    return ($self->GetCoreError) if(!$result);
	    
	    my $cg_id = $self -> GetCgIdFromPse($pre_pse_id);
	    return 0 if($cg_id == 0);
	    
	    $result = $self ->{'CoreSql'}-> InsertDNAPSE($cg_id, $event_pse_id, $avail_plate_locs->[$count]);
	    return 0 if($result == 0);
	    

	    push(@{$pse_ids}, $event_pse_id);

	}
	$count++;
    }


    return $pse_ids;
} #CreateGlycerolGrowth

############################################################
# Create a final dna archive of growths in a 96 well plate #
############################################################
sub CreateFinalDnaArchive {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = [];
    my $count = 0;
    my $event_pse_id;
    my $result;

    my $avail_plate_locs =  $self -> GetAvailableLocationsInGrowthPlate($bars_in->[0]);
    return 0 if(!$avail_plate_locs);

    my $purpose = Query($self->{'dbh'}, qq/select purpose from process_steps where ps_id = $ps_id/);
    my $final_dna_ps_id;
    if($purpose eq 'Growth Prep') {
	$final_dna_ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Growth Prep', 'finalize dna', 'run on concentration gel', 'none', 'library core');
    }
    else {
	$final_dna_ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Short Growth Prep', 'finalize dna', 'run on concentration gel', 'none', 'library core');
    }
    return ($self->GetCoreError) if(!$final_dna_ps_id);

    my $lib_set_ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Library Construction', 'confirm digest', 'assign to library set', 'none', 'library core');
    return ($self->GetCoreError) if(!$lib_set_ps_id);

    foreach my $finaldna_bar (@{$bars_out}) {

	if(!($finaldna_bar =~ /^empty/)) {
	    my $pre_bar_dir = 'out';
	    my $pre_pse_status = 'completed';
	    
	    $pre_pse_ids = $self->{'CoreSql'}->Process('GetPrePseForBarcode', $finaldna_bar, $pre_bar_dir, $pre_pse_status, $final_dna_ps_id);
	    return ($self->GetCoreError) if(! defined $pre_pse_ids->[0]);
	    
	    my $pre_pse_id = $pre_pse_ids->[0];
	    
	    if(($count==0) || (! defined $event_pse_id)) {
		$event_pse_id =  $self->{'CoreSql'}->Process('GetNextPse');
		return ($self->GetCoreError) if(!$event_pse_id);
		
		#PSE_SESSION,PSESTA_PSE_STATUS, PR_PSE_RESULT, PS_PS_ID, EI_EI_ID, PSE_ID, EI_EI_ID_CONFIRM, PIPE
		$result = $self->{'CoreSql'}->Process('InsertPseEvent', '0','completed', 'successful', $ps_id, $emp_id, $event_pse_id, $emp_id, 0, $pre_pse_id);
		return ($self->GetCoreError) if(!$result);
		
		#bs_barcode, pse_pse_id, direction
		$result = $self->{'CoreSql'}->Process('InsertBarcodeEvent', $bars_in->[0], $event_pse_id, 'out');
		return ($self->GetCoreError) if(!$result);
	    }    
	    
	    $result = $self->{'CoreSql'}->Process('InsertBarcodeEvent', $finaldna_bar, $event_pse_id, 'in');
	    return ($self->GetCoreError) if(!$result);
	    
	    my $cg_id = $self -> GetCgIdFromPse($pre_pse_id);
	    return 0 if($cg_id == 0);
	    
	    $result = $self ->{'CoreSql'}-> InsertDNAPSE($cg_id, $event_pse_id, $avail_plate_locs->[$count]);
	    return 0 if($result == 0);
	    
	    my $lib_set_pse = $self -> GetPseIdFromCgIdPsId($cg_id, $lib_set_ps_id);
	    return 0 if($lib_set_pse == 0);
	    
	    $result =  $self->{'CoreSql'}->Process('UpdatePse', 'completed', 'successful', $lib_set_pse);
	    return ($self->GetCoreError) if(!$result);
	    
	    push(@{$pse_ids}, $event_pse_id);
	}
	
	$count++;
    }


    return $pse_ids;
} #CreateFinalDnaArchive


#######################################################
# Create a new library for a clone at sonication step #
#######################################################
sub CreateLibrary {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $cg_id = $self -> GetCgIdFromPse($pre_pse_id);
    return 0 if($cg_id == 0);

    my $new_pse_id =  $self->{'CoreSql'}->Process('GetNextPse');
    return ($self->GetCoreError) if(!$new_pse_id);
	    
    #PSE_SESSION,PSESTA_PSE_STATUS, PR_PSE_RESULT, PS_PS_ID, EI_EI_ID, PSE_ID, EI_EI_ID_CONFIRM, PIPE
    my $result = $self->{'CoreSql'}->Process('InsertPseEvent', '0','inprogress', '', $ps_id, $emp_id, $new_pse_id, $emp_id, 0, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$result);
    
    $result = $self->{'CoreSql'}->Process('InsertBarcodeEvent', $bars_in->[0], $new_pse_id, 'in');
    return ($self->GetCoreError) if(!$result);
    
    #bs_barcode, pse_pse_id, direction
    $result = $self->{'CoreSql'}->Process('InsertBarcodeEvent', $bars_out->[0], $new_pse_id, 'out');
    return ($self->GetCoreError) if(!$result);

    # get next cl_id 
    my $cl_id = $self->GetNextClId;
    return 0 if(!$cl_id);
    
    #get next library number
    my $library_number = $self->GetNextLibraryNumber;
    return 0 if(!$library_number);

    #insert new library
    $result = $self->InsertCloneLibraries($cl_id, $library_number, $cg_id, $new_pse_id);
    return 0 if($result == 0);

    #insert clone growth library
#    $result = $self->InsertCloneGrowthsLibraries($cg_id, $cl_id);
#    return 0 if($result == 0);

#    $result = $self -> InsertCloneLibrariesPses($cl_id, $new_pse_id, '');
#    return 0 if($result == 0);

    push(@{$pse_ids}, $new_pse_id);
    return $pse_ids;

} #CreateLibrary


#######################################################
# Create a new library for a clone at sonication step #
#######################################################
sub CreateShatterLibrary {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
    return ($self->GetCoreError) if(!$result);

    my $sub_id = $self -> GetSubIdFromPse($pre_pse_id);
    return 0 if($sub_id == 0);

    my $cg_id = $self -> GetCgIdFromSubId($sub_id);
    return 0 if($cg_id == 0);

    my $new_pse_id = $self -> {'CoreSql'} -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'inprogress', '', $emp_id, undef, $pre_pse_id);
    return ($self->GetCoreError) if(!$new_pse_id);

    # get next cl_id 
    my $cl_id = $self->GetNextClId;
    return 0 if(!$cl_id);
    
    #get next library number
    my $library_number = $self->GetNextLibraryNumber;
    return 0 if(!$library_number);

    #insert new library
    $result = $self->InsertCloneLibraries($cl_id, $library_number, $sub_id, $new_pse_id);
    return 0 if($result == 0);

#    $result = $self->UpdateCloneLibrarySubId($cl_id, $sub_id);
#    return 0 if($result == 0);

    #insert clone growth library
#    $result = $self->InsertCloneGrowthsLibraries($cg_id, $cl_id);
#    return 0 if($result == 0);

#    $result = $self -> InsertCloneLibrariesPses($cl_id, $new_pse_id, '');
#    return 0 if($result == 0);

    push(@{$pse_ids}, $new_pse_id);
    return $pse_ids;

} #CreateLibrary

#########################
# Load a sonication Gel #
#########################
sub LoadSonicationGel1 {

   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   
   my $result = $self -> LoadGel($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, 1, $GelPositions1, 'sonication gel');

   return $result;
} #LoadSonicationGel1
#########################
# Load a sonication Gel #
#########################
sub LoadSonicationGel2 {

   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   
   my $result = $self -> LoadGel($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, 2, $GelPositions2, 'sonication gel');

   return $result;
} #LoadSonicationGel1
#########################
# Load a sonication Gel #
#########################
sub LoadSonicationGel3 {

   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   
   my $result = $self -> LoadGel($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, 3, $GelPositions3, 'sonication gel');

   return $result;
} #LoadSonicationGel1

#########################
# Load a fraction quantitation Gel #
#########################
sub LoadFractionQuantitationGel1 {

   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   
   my $result = $self -> LoadGel($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, 1, $GelPositions1, 'fraction quantitation gel');

   return $result;
} #LoadFractionQuantitationGel1
#########################
# Load a fraction quantitation Gel #
#########################
sub LoadFractionQuantitationGel2 {

   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   
   my $result = $self -> LoadGel($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, 2, $GelPositions2, 'fraction quantitation gel');

   return $result;
} #LoadFractionQuantitationGel1
#########################
# Load a fraction quantitation Gel #
#########################
sub LoadFractionQuantitationGel3 {

   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   
   my $result = $self -> LoadGel($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, 3, $GelPositions3, 'fraction quantitation gel');

   return $result;
} #LoadFractionQuantitationGel1

#########################
# Load a dilution Gel #
#########################
sub LoadDilutionGel1 {

   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   
   my $result = $self -> LoadGel($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, 1, $GelPositions1, 'dilution gel');

   return $result;
} #LoadDilutionGel1
#########################
# Load a dilution Gel #
#########################
sub LoadDilutionGel2 {

   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   
   my $result = $self -> LoadGel($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, 2, $GelPositions2, 'dilution gel');

   return $result;
} #LoadDilutionGel1
#########################
# Load a dilution Gel #
#########################
sub LoadDilutionGel3 {

   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   
   my $result = $self -> LoadGel($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, 3, $GelPositions3, 'dilution gel');

   return $result;
} #LoadDilutionGel1

############################
# Load a concentration Gel #
############################
sub LoadConcentrationGel {

   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   
   my $result = $self -> LoadGel($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, 1, $GelPositions1, 'concentration gel');

   return $result;
} #LoadConcentrationGel


#################################
# Load a shatter sonication Gel #
#################################
sub LoadShatterSonicationGel{

   my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
   
   my $result = $self -> LoadGel($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, 1, $GelPositions1, 'shatter sonication gel');

   return $result;
} #LoadConcentrationGel


############
# Load Gel #
############
sub LoadGel {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, $gel_num, $gelpositions, $gel_type) = @_;

    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my %get_query = ('sonication gel' => 'GetClIdFromPse',
		     'fraction quantitation gel'   => 'GetFraIdFromPse',
		     'dilution gel'   => 'GetLigIdFromPse',
		     'concentration gel' => 'GetSubIdFromPse', 
		     'shatter sonication gel' => 'GetClIdFromPse',);
    my %set_query = ('sonication gel' => 'InsertDNAPSE',
		     'fraction quantitation gel'   => 'InsertDNAPSE',
		     'dilution gel'   => 'InsertDNAPSE',
		     'concentration gel' => 'InsertDNAPSE',
		     'shatter sonication gel' => 'InsertDNAPSE',);
    
    my %info_query = ('sonication gel' => 'GetLibraryCloneSetFromPse',
		      'fraction quantitation gel'   => 'GetLibraryCloneSetFractionFromPse',
		      'dilution gel'   => 'GetLibraryCloneSetLigationFromPse',
		      'concentration gel' => 'GetSubcloneCloneFromPse',
		      'shatter sonication gel' => 'GetShatterLibraryFromPse',);
    
    my %table_header = ('sonication gel' => ['Lane', 'Library', 'Clone', 'Lib Set'],
			'fraction quantitation gel'   => ['Lane', 'Library', 'Clone', 'Lib Set', 'Fraction'],
			'dilution gel'   =>  ['Lane', 'Library', 'Clone', 'Lib Set', 'Ligation'],
			'concentration gel' => ['Lane', 'Subclone', 'Clone', 'Library'],
			'shatter sonication gel' => ['Lane', 'Subclone', 'Clone', 'Library'],
			);
    
		      
    my $i=0;
    my $table_info = [];
    my @lane_names;
    my $tpos=0;
    
    for($i=0; $i<=$#{$gelpositions}; $i++) {
	
	if(defined $bars_out->[$i]) {
	    my $bar_out = $bars_out->[$i];
	    my $lane = $gelpositions->[$i];
	    
	    if($lane =~ /^Lane\s([1-9]|[0-9][0-9])$/) {
		my $gel_lane = $1;
		
		$pre_pse_ids = $self->{'CoreSql'}->{'GetPrePseForBarcode'}->xSql($bar_out, 'out', 'inprogress', $ps_id);
		if(! defined $pre_pse_ids) {
		    $pre_pse_ids = $self->{'CoreSql'}->{'GetPrePseForBarcode'}->xSql($bar_out, 'in', 'inprogress', $ps_id);
		    if(! defined $pre_pse_ids) {
			$self->{'Error'} = "$pkg: LoadGel() -> Could not find pse_id.";
			return 0;
		    }
		}
		my $pre_pse_id = $pre_pse_ids->[0];
		
		my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bar_out, [$bars_in->[0]], $emp_id);
		return ($self->GetCoreError) if(!$new_pse_id);
		
		my $get_query = $get_query{$gel_type};
		my $set_query = $set_query{$gel_type};
		my $info_query = $info_query{$gel_type};

		
		my $id = $self ->  $get_query($pre_pse_id);
		return 0 if($id == 0);

		my $result = $self ->{'CoreSql'}-> $set_query($id, $new_pse_id, $gel_lane + 1000);

		
		return 0 if($result == 0);
		
		my $lol = $self->{$info_query}->xSql($pre_pse_id);
		
		$table_info->[$tpos][0] = $gel_lane;
		$table_info->[$tpos][1] = $lol->[0][0];
		$table_info->[$tpos][2] = $lol->[0][1];
		$table_info->[$tpos][3] = $lol->[0][2];
		$table_info->[$tpos][4] = $lol->[0][3] if(($gel_type eq 'fraction quantitation gel') || ($gel_type eq 'dilution gel'));
		
		
		$lane_names[$i] = $lol->[0][0];
		push(@{$pse_ids}, $new_pse_id);
		$tpos++;
	    }
	    else {
		$lane_names[$i] = $lane;
	    }
	}
	else {
	    $lane_names[$i] = 'Marker';
	    last;
	}
    }
    
    $lane_names[$i++] = 'Marker' if($#{$gelpositions} == $#{$bars_out});
    
    my $date = Query($self->{'dbh'}, "select trunc(sysdate) from dual");
    
    my $user = Query($self->{'dbh'}, "select unix_login from gsc_users where gu_id in (select gu_gu_id from employee_infos where ei_id = '$emp_id')");
    
    my $table_header = $table_header{$gel_type};
    
    $self -> CreateGelInfoSheets($bars_in->[0], $gel_num, $user, $date, $gel_type, $table_header, $table_info, $#{$gelpositions}+2, \@lane_names); 
    return $pse_ids;

}

#######################
# Load a Fraction Gel #
#######################
sub LoadFractionGel {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $i=0;
    my $table_info = [];
    my (@lane_names_top, @lane_names_bot);
    my $tpos=0;
    my $gelpositions = $FractionGelPositions;
    for($i=0; $i<=$#{$gelpositions}; $i++) {
	
	if(defined $bars_out->[$i]) {
	    my $bar_out = $bars_out->[$i];
	    my $lane = $gelpositions->[$i];
	    
	    if($lane =~ /^Lane\s([1-9]|[0-9][0-9])$/) {
		my $gel_lane = $1;
		
		$pre_pse_ids = $self->{'CoreSql'}->{'GetPrePseForBarcode'}->xSql($bar_out, 'out', 'inprogress', $ps_id);
		if(! defined $pre_pse_ids) {
		    $pre_pse_ids = $self->{'CoreSql'}->{'GetPrePseForBarcode'}->xSql($bar_out, 'in', 'inprogress', $ps_id);
		    if(! defined $pre_pse_ids) {
			$self->{'Error'} = "$pkg: LoadFractionGel() -> Could not find pse_id.";
			return 0;
		    }
		}
		my $pre_pse_id = $pre_pse_ids->[0];
		
		my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bar_out, [$bars_in->[0]], $emp_id);
		return ($self->GetCoreError) if(!$new_pse_id);
		
		my $cl_id = $self -> GetClIdFromPse($pre_pse_id);
		return 0 if($cl_id == 0);
		
		my $result = $self->{'CoreSql'} -> InsertDNAPSE($cl_id, $new_pse_id, $gel_lane+1000);
		return 0 if($result == 0);
		
		my $lol = $self->{'GetLibraryCloneSetFromPse'}->xSql($pre_pse_id);

		$table_info->[$tpos][0] = $gel_lane;
		$table_info->[$tpos][1] = $lol->[0][0];
		$table_info->[$tpos][2] = $lol->[0][1];
		$table_info->[$tpos][3] = $lol->[0][2];
		
		if($gel_lane <=12) {
		    $lane_names_top[$i] = $lol->[0][0];
		}
		else {
		    $lane_names_bot[$i-12] = $lol->[0][0];
		}
		push(@{$pse_ids}, $new_pse_id);
		$tpos++;
	    }
	}
	else {
	    last;
	}
    }
    
    my $date = Query($self->{'dbh'}, "select trunc(sysdate) from dual");
    
    my $user = Query($self->{'dbh'}, "select unix_login from gsc_users where gu_id in (select gu_gu_id from employee_infos where ei_id = '$emp_id')");
    
    my $table_header = ['Lane', 'Library', 'Clone', 'Lib Set'];
    
    $self -> CreateGelInfoSheets($bars_in->[0], 1, $user, $date, 'fraction gel', $table_header, $table_info, 12, \@lane_names_top, \@lane_names_bot); 
    return $pse_ids;

}

			 


sub CreateGelInfoSheets {
			 
    my ($self, $barcode, $gel_number, $user, $date, $gel_type, $table_header, $table_info, $num_lanes, $lane_info1, $lane_info2) = @_;

    my $gif_file = '/tmp/barcode.png';
    my $ps_file = '/tmp/barcode.ps';
    my $backup = "/tmp/GelInfoSheet.$barcode";

    open(FILE, ">$backup");

    print FILE "barcode = $barcode\n";
    print FILE "gel number = $gel_number\n";
    print FILE "user = $user\n";
    print FILE "date = $date\n";
    print FILE "gel type = $gel_type\n";
    my $col=0;
    my $i= 0;
    foreach my $column (@{$table_header}) {
	
	print FILE "column header = $column\n";
	for($i=0;$i<=$#{$table_info};$i++) {
	    print FILE "info = ".$table_info->[$i][$col]."\n";
	}
	$col++;
    }

    print FILE "num lanes = $num_lanes\n";
    
    print FILE "lane info 1 = @{$lane_info1}\n";
    print FILE "lane info 2 = @{$lane_info2}\n" if(defined $lane_info2);
    
    close(FILE);

    my $bar_image = new BarcodeImage($barcode,10,"bw",1,200,"interlaced", '');
    
    my $log_sheet = TouchScreen::GelImageLogSheet->new(500, 700);

    $log_sheet -> InsertBarcode($bar_image->{gd_image}, 300, 15);
    
    $log_sheet -> InsertString(50, 25, "Gel Type   : $gel_type");
    $log_sheet -> InsertString(50, 35, "Technician : $user");
    $log_sheet -> InsertString(50, 45, "Date       : $date");
    $log_sheet -> InsertString(50, 55, "Gel Number : $gel_number");
   

    my $x = 50;
    my $y = 70;
    my $incrX = 75;
    my $incrY = 10;

    $col = 0;
    foreach my $column (@{$table_header}) {
	
	$y = 70;

	$log_sheet -> InsertString($x, $y, $column);

	for($i=0;$i<=$#{$table_info};$i++) {
	    $y+= $incrY;
	    $log_sheet -> InsertString($x, $y, $table_info->[$i][$col]) if(defined $table_info->[$i][$col]);
	}
	if($column eq 'Lane') {
	    $x+= 35;
	}
	elsif($column eq 'Library') {
	    $x+= 50;
	}
	elsif($column eq 'Clone') {
	    $x+= 80;
	}
	elsif($column eq 'Lib Set') {
	    $x+= 50;
	}
	else {
	    $x+= $incrX;
	}
	$col++;
    }

    my $under='';
    for($i=0; $i<$x/6; $i++) {
	$under = $under.'_';
    }

    $log_sheet -> InsertString(50, 70, $under);

    $log_sheet -> CreateGelImage(50, 365, 320, 285, $num_lanes, $lane_info1, $lane_info2);
    
    my $gif_image = $log_sheet->CreateImage;
    

    open(GIF, ">$gif_file") || die("Can't open GIF file");
    binmode GIF;
    print GIF $gif_image;
    close(GIF);
    

    `lpr -o scaling=100 $gif_file`;
    
}

sub CheckSonicationGel {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $data_options = $options->{'Data'};
    my $data = $data_options->{'status'};
    my $status = $$data;
    my $pses = $self->ProcessLibrary($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids);
    
    
    foreach my $pse (@{$pses}) {
	if($status eq 'pass') {
	    my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pse);
	    return ($self->GetCoreError) if(!$result);
	}
	else {
	    my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'unsuccessful', $pse);
	    return ($self->GetCoreError) if(!$result);
	}
    }

    return $pses;

}


##########################
# Process a library step #
##########################
sub ProcessLibraryResonicate {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    my $update_status = 'completed';
    my $update_result = 'unsuccessful';

    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    return ($self->GetCoreError) if(!$new_pse_id);

    my $cl_id = $self -> GetClIdFromPse($pre_pse_id);
    return 0 if($cl_id == 0);
    
    #my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
    my $dl_id = $self->getTubeLocation;

    my $result = $self->{'CoreSql'} -> InsertDNAPSE($cl_id, $new_pse_id, $dl_id );
    return 0 if($result == 0);

    push(@{$pse_ids}, $new_pse_id);
    return $pse_ids;
} #ProcessLibrary


##########################
# Process a library step #
##########################
sub ProcessLibrary {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    return ($self->GetCoreError) if(!$new_pse_id);

    my $cl_id = $self -> GetClIdFromPse($pre_pse_id);
    return 0 if($cl_id == 0);

    #my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
    my $dl_id = $self->getTubeLocation;
    
    my $result = $self->{'CoreSql'} -> InsertDNAPSE($cl_id, $new_pse_id, $dl_id);
    return 0 if($result == 0);

    push(@{$pse_ids}, $new_pse_id);
    return $pse_ids;
} #ProcessLibrary




#########################################################
# Create a new fractions for a clone at sonication step #
#########################################################
sub CreateFractions {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $cl_id = $self -> GetClIdFromPse($pre_pse_id);
    return 0 if($cl_id == 0);
 
    my $i;
    my @fractions = ('1-1.5kb', '1.5-2kb', '2-4kb'); 
    my @min = qw(1 1.5 2);
    my @max = qw(1.5 2 4);

    for($i=0;$i<3;$i++) {
	if($bars_out->[$i] ne 'empty') {
	    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bars_out->[$i]], $emp_id);
	    return ($self->GetCoreError) if(!$new_pse_id);

	    # get next fra_id 
	    my $fra_id = $self->GetNextFraId;
	    return 0 if(!$fra_id);

	    my $result = $self->InsertFractions($fra_id, $fractions[$i], $cl_id, $min[$i], $max[$i], $new_pse_id);
	    return 0 if($result == 0);
    
#	    $result = $self -> InsertFractionsPses($fra_id, $new_pse_id. '');
#	    return 0 if($result == 0);
	    
	    push(@{$pse_ids}, $new_pse_id);
	}
    }
	
    return $pse_ids;

} #CreateFractions



#########################################################
# Create a new fractions for a clone at sonication step #
#########################################################
sub CreateFractions3_65 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $cl_id = $self -> GetClIdFromPse($pre_pse_id);
    return 0 if($cl_id == 0);
 
    my $i;
    my @fractions = ('0.3-0.5kb', '4-6.5kb', '6.5-9.5kb'); 
    my @min = qw(0.3 4 6.5);
    my @max = qw(0.5 6.5 9.5);

    for($i=0;$i<3;$i++) {
	if($bars_out->[$i] ne 'empty') {
	    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bars_out->[$i]], $emp_id);
	    return ($self->GetCoreError) if(!$new_pse_id);

	    # get next fra_id 
	    my $fra_id = $self->GetNextFraId;
	    return 0 if(!$fra_id);

	    my $result = $self->InsertFractions($fra_id, $fractions[$i], $cl_id, $min[$i], $max[$i], $new_pse_id);
	    return 0 if($result == 0);
    
#	    $result = $self -> InsertFractionsPses($fra_id, $new_pse_id. '');
#	    return 0 if($result == 0);
	    
	    push(@{$pse_ids}, $new_pse_id);
	}
    }
	
    return $pse_ids;

} #CreateFractions


############################
# Process a fraction step  #
############################
sub ProcessFraction {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    return ($self->GetCoreError) if(!$new_pse_id);

    my $fra_id = $self -> GetFraIdFromPse($pre_pse_id);
    return 0 if($fra_id == 0);
    
    #my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
    my $dl_id = $self->getTubeLocation;
    my $result = $self->{'CoreSql'} -> InsertDNAPSE($fra_id, $new_pse_id, $dl_id);
    return 0 if($result == 0);

    push(@{$pse_ids}, $new_pse_id);
    return $pse_ids;
} #ProcessFraction


############################
# Process a fraction step  #
############################
sub ProcessFractionDilution {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $new_pse_id = $self -> {'CoreSql'} -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'completed', 'successful', $emp_id, undef, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$new_pse_id);

    my $fra_id = $self -> GetFraIdFromPse($pre_pse_ids->[0]);
    return 0 if($fra_id == 0);
    
    #my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
    my $dl_id = $self->getTubeLocation;

    my $result = $self ->{'CoreSql'}-> InsertDNAPSE($fra_id, $new_pse_id, $dl_id);
    return 0 if($result == 0);
    
    
    return [$new_pse_id];
} #ProcessFractionDilution


sub CheckFractionGel {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $data_options = $options->{'Data'};
    my $data = $data_options->{'status'};
    my $status = $$data;
    my $pses = $self->ProcessFraction($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids);
    
    
    foreach my $pse (@{$pses}) {
	if($status eq 'pass') {
	    my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pse);
	    return ($self->GetCoreError) if(!$result);
	}
	else {
	    my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'unsuccessful', $pse);
	    return ($self->GetCoreError) if(!$result);
	}
    }

    return $pses;

}


####################################
# Process to create a new ligation #
####################################
sub CreateLigation {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $reagent_vector = $options->{'Reagents'}->{'Vector'}->{'barcode'};

#    my $vl_id = $options->{'GetVlIdfromReagent'};
    my $vl_id = $self->GetVlIdfromReagent($reagent_vector);
    if(!defined $vl_id) {
	$self->{'Error'} = "$pkg: CreateLigation() -> vl_id not defined.";
	return 0;
    }

    my $fra_id = $self -> GetFraIdFromPse($pre_pse_id);
    return 0 if($fra_id == 0);

    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    return ($self->GetCoreError) if(!$new_pse_id);

    # get next lig_id 
    my $lig_id = $self->GetNextLigId;
    return 0 if(!$lig_id);
    
#    my $ligation_name = $self -> GetNextLigation($fra_id, $vl_id);
#    return 0 if(!$ligation_name);

    my $result = $self -> InsertLigations($lig_id, undef, $vl_id, $fra_id, $new_pse_id);
    return 0 if($result == 0);

#    $result = $self -> InsertLigationsPses($lig_id, $new_pse_id, '');
#    return 0 if($result == 0);

    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;
} #CreateLigation

#######################################################################################
# Process a growth step that has a previous step Inprogress and barcode was an output #
#######################################################################################
sub ProcessLigation {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    return ($self->GetCoreError) if(!$new_pse_id);

    my $lig_id = $self -> GetLigIdFromPse($pre_pse_id);
    return 0 if($lig_id == 0);
    
    #my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
    my $dl_id = $self->getTubeLocation;

    my $result = $self->{'CoreSql'} -> InsertDNAPSE($lig_id, $new_pse_id,$dl_id);
    return 0 if($result == 0);

    push(@{$pse_ids}, $new_pse_id);
    return $pse_ids;
} #ProcessLigation

sub ProcessLigation_with_no_completion {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    #my $update_status = 'completed';
    #my $update_result = 'successful';
    my $update_status = 'inprogress';
    my $update_result = '';

    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    return ($self->GetCoreError) if(!$new_pse_id);

    my $lig_id = $self -> GetLigIdFromPse($pre_pse_id);
    return 0 if($lig_id == 0);
    
    #my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
    my $dl_id = $self->getTubeLocation;

    my $result = $self->{'CoreSql'} -> InsertDNAPSE($lig_id, $new_pse_id,$dl_id);
    return 0 if($result == 0);

    push(@{$pse_ids}, $new_pse_id);
    return $pse_ids;
} #ProcessLigation

sub CheckLigationGel {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $data_options = $options->{'Data'};
    my $data = $data_options->{'status'};
    my $status = $$data;
    my $pses = $self->ProcessLigation($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids);
    
    
    foreach my $pse (@{$pses}) {
	if($status eq 'pass') {
	    my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pse);
	    return ($self->GetCoreError) if(!$result);
	}
	else {
	    my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'unsuccessful', $pse);
	    return ($self->GetCoreError) if(!$result);
	}
    }

    return $pses;

}

sub CheckSubcloneGel {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $data_options = $options->{'Data'};
    my $data = $data_options->{'status'};
    my $status = $$data;
    my $pses = $self->ProcessSubclone($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids);
    
    
    foreach my $pse (@{$pses}) {
	if($status eq 'pass') {
	    my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pse);
	    return ($self->GetCoreError) if(!$result);
	}
	else {
	    my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'unsuccessful', $pse);
	    return ($self->GetCoreError) if(!$result);
	}
    }

    return $pses;

}

###################
# dilute ligation #
###################
sub DiluteLigation {
  
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $new_pses = [];
    my ($pses) = $self -> ProcessLigation($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids);

    foreach my $pse_id (@$pre_pse_ids) {
        my $result =  $self->{'CoreSql'}->Process('UpdatePse', 'inprogress', '', $pse_id);!
        return ($self->GetCoreError) if(!$result);
    }
=cut
    return 0 if(! App::DB->sync_database());

    my $vector_type = $self->{'GetLigationVectorType'} -> xSql($bars_out->[0], 'out');
    
    if($vector_type =~ /mid$/) {
	my $retire_ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Ligation', 'ligate fraction', 'retire ligation', 'none', 'library core');

	foreach my $retire_pse_id (@{$pses}) {
	    
	    my $retire_pse = $self -> {'CoreSql'} -> BarcodeProcessEvent($retire_ps_id, $bars_in->[0], undef, 'completed', 'successful', $emp_id, undef, $pre_pse_ids->[0]);
	    return 0 if ($retire_pse == 0);

	    my $lig_id = $self -> GetLigIdFromPse($pre_pse_ids->[0]);
	    return 0 if($lig_id == 0);

	    #my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
            my $dl_id = $self->getTubeLocation;
	    my $result = $self->{'CoreSql'} -> InsertDNAPSE($lig_id, $retire_pse,$dl_id);
	    return 0 if($result == 0);
	    
	}
    }
=cut
    push(@{$new_pses}, @{$pses});
 
    return $new_pses;
} #RetireDilutionOrLigation


##################################
# Confirm ligation dilution step #
##################################
sub ConfirmDilution {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my ($target, $purpose, $titer, $pick_qc, $priority);

    $titer = '';
    my $data_options = $options->{'Data'};
    foreach my $pso (keys %{$data_options}) {
	my $desc = $self->{'GetPsoDescription'} -> xSql($pso);
	my $data = $data_options->{$pso};
	if(defined $$data) {

	    $target = $$data if($desc eq 'target');
	    $purpose = $$data if($desc eq 'purpose');
	    $titer = $$data if($desc eq 'titer');
	    $pick_qc = $$data if($desc eq 'pick qc');
	    $priority = $$data if($desc eq 'priority');
	    
	}
	else {
	    if($desc ne 'titer') {
		$self->{'Error'} = "$pkg: ConfirmDilution() -> $desc parameter not set.";
		return 0;
	    }
	}
    }
    
    # Set priority to 1 or 0
    if($priority eq 'yes') {
	$priority = 1;
    }
    else {
	$priority = 0;
    }

    # If pick qc = yes then add one to target amount
    #if($pick_qc eq 'yes') {
    #$target++;
    #}

    # Process Ligation step
    my $pse_ids = $self -> ProcessLigation($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, 'in', 'inprogress');

    
    # Get Ligation id
    my $lig_id = $self -> GetLigIdFromPse($pre_pse_ids->[0]);
    return 0 if($lig_id == 0);

    # update ligation info
    my $result = $self -> UpdateLigation($lig_id, $titer);
    return 0 if(!$result);
 
   
    # get clone id
    my $clo_id = $self -> GetCloIdForLigId($lig_id);
    return 0  if(!$clo_id);
    
    my $new_project = 0;
    # determine if new project or existing 
    
    # this query returns:
    # proj id, proj name, clone name
    my $lol_proj_id_name = $self->{'GetProjectFromCloneID'} -> xSql($clo_id);

    # locate projects whose name exactly matches clone name
    my @proj_clone_name_matches = grep {$_->[1] eq $_->[2]} @$lol_proj_id_name;

    my $project_id;

    if (scalar @$lol_proj_id_name == 0) {
	# absolutely NO projects match this clone.  this, and only this,
	# is a valid case for creating a new project.
	$new_project = 1;
    } elsif (scalar @proj_clone_name_matches > 1) {
	# more than one project had the same name.  
	# this shouldn't ever happen, but account for it just in case.
	$self->{'Error'} = "$pkg: ConfirmDilution: More than one project with same name matching clone name.";
	return 0;
    } elsif (scalar @proj_clone_name_matches == 0) {
	# this clone is associated with projects, but none's name matched the clone name.
	# raise an error rather than risk creating bad data.
	$self->{'Error'} = "$pkg: ConfirmDilution: Clone part of multiple projects but none match clone name.";
	return 0;
    } else {
	$project_id = $proj_clone_name_matches[0]->[0];
    }
	
    # Get project process step
    my $project_ps_id = $self->{'CoreSql'}->Process('GetPsId', 'Project Management', 'confirm dilution', 'new project', 'none', 'library core');
    return ($self->GetCoreError) if(!$project_ps_id);
    
    my $new_project_pse = 0;
    #check if new project pse exists, if it is not a new project
    if(!$new_project) {
	my $new_pse = $self -> GetNewProjectPse($project_ps_id, $project_id);
	if(!$new_pse) {
	    $new_project_pse = 1;
	}
    }

    if($new_project) {
	# Get next pse_id
	my $new_pse_id =  $self->{'CoreSql'}->Process('GetNextPse');
	return ($self->GetCoreError) if(!$new_pse_id);
	
	#PSE_SESSION,PSESTA_PSE_STATUS, PR_PSE_RESULT, PS_PS_ID, EI_EI_ID, PSE_ID, EI_EI_ID_CONFIRM, PIPE
	$result = $self->{'CoreSql'}->Process('InsertPseEvent', '0','completed', 'successful', $project_ps_id, $emp_id, $new_pse_id, $emp_id, 0, $pre_pse_ids->[0]);
	return ($self->GetCoreError) if(!$result);
	
	$project_id = $self -> InsertNewProject($clo_id, $purpose, $target, $priority, $new_pse_id);
	return 0 if(!$project_id);

#	$result = $self -> InsertProjectsPses($project_id, $new_pse_id);
#	return 0 if(!$result);
    }
    elsif($new_project_pse) {
	# Get next pse_id
	my $new_pse_id =  $self->{'CoreSql'}->Process('GetNextPse');
	return ($self->GetCoreError) if(!$new_pse_id);
	
	#PSE_SESSION,PSESTA_PSE_STATUS, PR_PSE_RESULT, PS_PS_ID, EI_EI_ID, PSE_ID, EI_EI_ID_CONFIRM, PIPE
	$result = $self->{'CoreSql'}->Process('InsertPseEvent', '0','inprogress', '', $project_ps_id, $emp_id, $new_pse_id, $emp_id, 0, $pre_pse_ids->[0]);
	return ($self->GetCoreError) if(!$result);

	$result = $self -> InsertProjectsPses($project_id, $new_pse_id);
	return 0 if(!$result);

	$result = $self -> UpdateProject($project_id, $purpose, $target, $priority);
	return 0 if(!$result);
    }
    else {
	$result = $self -> UpdateProject($project_id, $purpose, $target, $priority);
	return 0 if(!$result);
    }

    return $pse_ids;
}

###############################
# retire dilution or ligation #
###############################
sub RetireDilutionOrLigation {
  
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my ($pses) = $self -> ProcessLigation($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids);

    foreach my $pse (@{$pses}) {
	my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pse);
	return ($self->GetCoreError) if(!$result);
    }

    return $pses;
} #RetireDilutionOrLigation


#######################################################################################
# Process a growth step that has a previous step Inprogress and barcode was an output #
#######################################################################################
sub ProcessElectroporate {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $pre_pse_id = $pre_pse_ids->[0];
    #LSF: Will leave this inprogress.  It will be completed by the "retire electroporation tube" step.
    #my $update_status = 'completed';
    #my $update_result = 'successful';
    my $update_status = 'inprogress';
    my $update_result = '';

    my $lig_id = $self -> GetLigIdFromPse($pre_pse_id);
    return 0 if($lig_id == 0);
    
    foreach my $bar_out (@{$bars_out}) {
	my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out], $emp_id);
	return ($self->GetCoreError) if(!$new_pse_id);

	#my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
        #my $dl_id = $self->getTubeLocation;
        my $dl = GSC::DNALocation->get(location_type => 'large square agar plate');

	my $result = $self->{'CoreSql'} -> InsertDNAPSE($lig_id, $new_pse_id, $dl->dl_id);
	return 0 if($result == 0);
	
	push(@{$pse_ids}, $new_pse_id);
    }

    return $pse_ids;
} #ProcessElectroporate

############################################################################
# Transfer 96 well plate of dna archive growths into another 96 well plate #
############################################################################
sub ProcessTransferGrowthsIn96WellPlate {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    my $pse_ids = [];

    foreach my $pre_pse_id (@{$pre_pse_ids}) {
	# update pse to completed
	my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pse_ids->[0]);
	return ($self->GetCoreError) if(!$result);
	
	my $pse_id =  $self->{'CoreSql'}->Process('GetNextPse');
	return ($self->GetCoreError) if(!$pse_id);
	
	#PSE_SESSION,PSESTA_PSE_STATUS, PR_PSE_RESULT, PS_PS_ID, EI_EI_ID, PSE_ID, EI_EI_ID_CONFIRM, PIPE
	$result = $self->{'CoreSql'}->Process('InsertPseEvent', '0','inprogress', '', $ps_id, $emp_id, $pse_id, $emp_id, 0, $pre_pse_ids->[0]);
	return ($self->GetCoreError) if(!$result);
	
	$result = $self->{'CoreSql'}->Process('InsertBarcodeEvent', $bars_in->[0], $pse_id, 'in');
	return ($self->GetCoreError) if(!$result);
	    
	#bs_barcode, pse_pse_id, direction
	$result = $self->{'CoreSql'}->Process('InsertBarcodeEvent', $bars_out->[0], $pse_id, 'out');
	return ($self->GetCoreError) if(!$result);

	my $cg_ids = $self -> {'GetCgIdsFromPse'} -> xSql($pre_pse_id);
	foreach my $cg_id (@{$cg_ids}) {
	    $result = $self->{'CoreSql'} -> InsertDNAPSE($cg_id->[0], $pse_id, $cg_id->[1]);
	    return 0 if($result == 0);
	}
	push(@{$pse_ids}, $pse_id);
    }

    return $pse_ids;

} #ProcessTransferGrowthsIn96WellPlate

###########################################
# fail agar plate after counting colonies #
###########################################
sub FailAgarPlate {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_ids->[0], 'completed', 'unsuccessful', $bars_in->[0], $bars_out, $emp_id);
    return ($self->GetCoreError) if(!$new_pse_id);

    my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $new_pse_id);
    return ($self->GetCoreError) if(!$result);
     
    return [$new_pse_id];

} #FailAgarPlate 

############################################################################################
#                                                                                          #
#                    Post Confirm Subrotine Processes                                      #
#                                                                                          #
############################################################################################

#############################################
# Update final dna growth step to completed #
#############################################
sub FinalizeDnaGrowth {

    my ($self, $pse_ids) = @_;

    foreach my $pse_id (@{$pse_ids}) {
    
	my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pse_id);
	return ($self->GetCoreError) if(!$result);
    
	$result = $self -> PrintCloneLabel($pse_id);
	return 0 if($result == 0);
    }

    return 1;
} #FinalizeDnaGrowth


############################################################################################
#                                                                                          #
#                      Information Retrevial Subrotines                                    #
#                                                                                          #
############################################################################################


###################################################
# Get a cl_id from pse_id in clone_libraries_pses #
###################################################
sub GetClIdFromPse {

    my ($self, $pse_id) = @_;
    my $cl_id = $self->{'GetClIdFromPse'}->xSql($pse_id);
    
    if($cl_id) {
	return $cl_id;
    }

    $self->{'Error'} = "$pkg: GetClIdFromPse()->pse_id = $pse_id";
    return 0;


} #GetClIdFromPse


#################################################
# Get a cg_id from pse_id in clone_growths_pses #
#################################################
sub GetCgIdFromPse {

    my ($self, $pse_id) = @_;
    my $cg_id = $self->{'GetCgIdFromPse'}->xSql($pse_id);
    
    if($cg_id) {
	return $cg_id;
    }

    $self->{'Error'} = "$pkg: GetCgIdFromPse()->pse_id = $pse_id";
    return 0;
} #GetCgIdFromPse

#################################################
#################################################
sub GetCgIdFromSubId {

    my ($self, $pse_id) = @_;
    my $cg_id = $self->{'GetCgIdFromSubId'}->xSql($pse_id);
    
    if($cg_id) {
	return $cg_id;
    }

    $self->{'Error'} = "$pkg: GetCgIdFromSubId()->pse_id = $pse_id";
    return 0;
} #GetCgIdFromPse


##############################################
# Get a fra_id from pse_id in fractions_pses #
##############################################
sub GetFraIdFromPse {

    my ($self, $pse_id) = @_;
    my $fra_id = $self->{'GetFraIdFromPse'}->xSql($pse_id);
    
    if($fra_id) {
	return $fra_id;
    }

    $self->{'Error'} = "$pkg: GetFraIdFromPse()->pse_id = $pse_id";
    return 0;
} #GetFraIdFromPse


##############################################
# Get a lig_id from pse_id in dna_pse #
##############################################
sub GetLigIdFromPse {

    my ($self, $pse_id) = @_;
    my $lig_id = $self->{'GetLigIdFromPse'}->xSql($pse_id);
    
    if($lig_id) {
	return $lig_id;
    }

    $self->{'Error'} = "$pkg: GetLigIdFromPse()->pse_id = $pse_id";
    return 0;
} #GetLigIdFromPse


##############################################
# Get a sub_id from pse_id in dna_pse #
##############################################
sub GetSubIdFromPse {

    my ($self, $pse_id) = @_;
    my $sub_id = $self->{'GetSubIdFromPse'}->xSql($pse_id);
    
    if($sub_id) {
	return $sub_id;
    }

    $self->{'Error'} = "$pkg: GetSubIdFromPse()->pse_id = $pse_id";
    return 0;
} #GetSubIdFromPse


sub GetPseIdFromCgIdPsId {
    
    my ($self, $cg_id, $ps_id) = @_;

    my $schema = $self->{'Schema'};

    my $sql = "select pse_id from process_step_executions where ps_ps_id = '$ps_id' and pse_id in 
               (select pse_pse_id from clone_growths_pses where cg_cg_id = '$cg_id')";
    my $pse_id = Query( $self ->{'dbh'}, $sql);
    if($pse_id) {
	return $pse_id;
    }
    $self->{'Error'} = "$pkg: GetPseIdFromCgIdPsId() -> Could not find pse_id from cg_id = $cg_id and ps_id = $ps_id.";

    return 0;
}

sub GetLibraryNumberFromClId {

    my ($self, $cl_id) = @_;
    my $schema = $self->{'Schema'};

    my $sql = "select library_number from  clone_libraries where cl_id = '$cl_id'";
    my $library_number = Query( $self ->{'dbh'}, $sql);
    if($library_number) {
	return $library_number;
    }
    $self->{'Error'} = "$pkg: GetLibraryNumberFromClId() -> Could not find library number for $cl_id.";

    return 0;
} #GetLibraryNumberFromClId


sub GetCloneNameFromCloId {

    my ($self, $clo_id) = @_;
    my $schema = $self->{'Schema'};

    my $sql = "select clone_name from  clones where clo_id = '$clo_id'";
    my $clone_name = Query( $self ->{'dbh'}, $sql);
    if($clone_name) {
	return $clone_name;
    }
    $self->{'Error'} = "$pkg: GetLibraryNumberFromClId() -> Could not find clone_name for $clo_id.";
 
    return 0;
} #GetLibraryNumberFromClId

sub GetProjectTarget {

    my ($self, $ps_id, $desc, $barcode) = @_;

    
    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});

    my ($pso_id, $data, $lov) = $TouchSql -> GetPsoInfo($ps_id, $desc);
    
    $TouchSql -> destroy;

    
    my $proj_data = $self -> {'GetProjectTargetFromBarcodePsId'} -> xSql($barcode->[0], $ps_id);
    
    if((defined $proj_data)&&($proj_data != 0)) {
	return ($pso_id, $proj_data, $lov);
	
    }
    
    my $clone = $self->{'GetProjectFromLigationBarcode'} -> xSql($barcode->[0]);

    my $clone_obj = GSC::Clone->get(clone_name => $clone);

    if($clone_obj->clone_type eq 'fosmid') {
        $data = '8';
    }
    elsif($clone =~ /^(Z_AG|Z_AH|Z_AF)/) {
        $data = '8';
    }
    else {
	$data = '20';
    }
    return ($pso_id, $data, $lov);

} #GetProjectTarget

sub GetProjectPurpose {

    my ($self, $ps_id, $desc, $barcode) = @_;

    
    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});

    my ($pso_id, $data, $lov) = $TouchSql -> GetPsoInfo($ps_id, $desc);
    
    $TouchSql -> destroy;

    $lov = Lquery($self->{'dbh'}, "select purpose from project_purposes");

    my $proj_data = $self -> {'GetProjectPurposeFromBarcodePsId'} -> xSql($barcode->[0], $ps_id);
   
    if(defined $proj_data) {
	return ($pso_id, $proj_data, $lov);
    }

    my $clone = $self->{'GetProjectFromLigationBarcode'} -> xSql($barcode->[0]);

    if($clone =~ /^M_/) {
	$data = '5X';
    }
    elsif($clone =~ /^Z_/){
        $data = '3.5X';
    }
    else {
	$data = '8X';
    }

    return ($pso_id, $data, $lov);

} #GetProjectPurpose

sub GetProjectPriority {

    my ($self, $ps_id, $desc, $barcode) = @_;

    
    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});

    my ($pso_id, $data, $lov) = $TouchSql -> GetPsoInfo($ps_id, $desc);
    
    $TouchSql -> destroy;

    my $proj_data = $self -> {'GetProjectPriorityFromBarcodePsId'} -> xSql($barcode->[0], $ps_id);
   
    if(defined $proj_data) {
	if($proj_data) {
	    return ($pso_id, 'yes', $lov);
	}
	else {
	    return ($pso_id, 'no', $lov);
	}
    }

    return ($pso_id, $data, $lov);

} #GetProjectPriority

sub GetCloIdForLigId {

    my ($self, $lig_id) = @_;
    
    my $schema = $self->{'Schema'};

    my $sql = "select clo_clo_id from clone_growths where cg_id in (
               select cg_cg_id from clone_growths_libraries where cl_cl_id in 
               (select cl_cl_id from fractions where fra_id in 
               (select fra_fra_id from ligations where lig_id = '$lig_id')))";
    my $clo_id = Query($self->{'dbh'}, $sql);
    
    if($clo_id) {
	return $clo_id;
    }
    
    $self->{'Error'} = "$pkg: GetCloIdForLigId() -> Could not clo_id for lig_id = $lig_id.";

    return 0;
} #GetCloIdForLigId
   

sub GetNewProjectPse {

    my ($self, $project_ps_id, $project_id) = @_;
    
    my $pse_id = $self -> {'GetNewProjectPse'} -> xSql($project_ps_id, $project_id);

    if(defined $pse_id) {
	return $pse_id;
    }

    $self->{'Error'} = "$pkg: GetNewProjectPse() -> No pse_id found for $project_ps_id, $project_id.";
    return 0;

}


sub GetCloneIdForNewGrowth {

    my ($self, $pre_pse_id) = @_;

    my $dp = GSC::DNAPSE->get(pse_id=>$pre_pse_id);
    
    if (!$dp) {
	$self->{'Error'} = "$pkg: GetCloneIdForNewGrowth() -> pse_id = $pre_pse_id no dnapses\n";
	return 0;
    }	
    my $dna = GSC::DNA->get($dp->dna_id);

    if ($dna->dna_type eq "clone") {
	return ($dna->dna_id, '');
    } elsif ($dna->dna_type eq "clone growth") {
	return ($dna->parent_dna_id, $dna->dna_id);
    } else {
	$self->{'Error'} = "$pkg: GetCloneIdForNewGrowth() -> pse_id = $pre_pse_id bogus dnapse: no clone/growth!\n";
	return 0;
    }	
	
} #GetCloneIdForNewGrowth

sub GetNextGrowthExtForClone {
    my ($self, $clo_id) = @_;
    my $dbh = $self ->{'dbh'};
    my $schema = $self->{'Schema'};
    #LSF: Do the hard way.
    my @gexts = map { $_->growth_ext } GSC::CloneGrowth->get(clo_id => $clo_id);
    if(! @gexts) {
      return "a";
    }
    my $me = "a";
    foreach my $e (@gexts) {
      if(length($e) > length($me)) {
        $me = $e;
      } elsif(length($e) == length($me)) {
        if($e gt $me) {
	  $me = $e;
        }
      }
    }
    $me ++;
    return $me;
} #GetNextGrowthExtForClone


sub GetNextLibraryNumber {

    my ($self) = @_;
#    my $db_query;
#    if($self->{'Schema'} eq 'gscuser') {
    my $db_query = $self->{'dbh'}->prepare(q{
	    BEGIN 
		:nextLib := gsc.ProductionName.NextLibraryNumber;
	    END;
	    
	});
		
#    }
#    else {
#	$db_query = $self->{'dbh'}->prepare(q{
#	    BEGIN 
#		:nextLib := tlakanen.ProductionName.NextLibraryNumber;
#	    END;
#	});
#    }

    my $db_answer;
    my $library_number;
    $db_query->bind_param_inout(":nextLib", \$library_number, 8);
    $db_query->execute;
    
    if(defined $library_number) {
	return $library_number;
    }

    $self->{'Error'} = "$pkg: GetNextLibraryNumber() -> Could not get next Library number.";
    return 0;
} #GetNextLibraryNumber

sub GetNextLigation {
    my ($self, $fra_id, $vl_id) = @_;

    my $dbh = $self ->{'dbh'};
    my $schema = $self->{'Schema'};
    
    my $sql = "select distinct vec_vec_id from vector_linearizations where vl_id = '$vl_id'";
    my $vec_id = Query($dbh, $sql);

    if($vec_id) {

	$sql = "select  distinct cl_cl_id from fractions where fra_id = '$fra_id'";
	my $cl_id = Query($dbh, $sql);
	
	if($cl_id) {
#	    my $db_query;
#	    if($self->{'Schema'} eq 'gscuser') {
	    my $db_query = $self->{'dbh'}->prepare(q{
		BEGIN 
		    :nextLig := gsc.ProductionName.NextLigationName(:cl_id, :vec_id);
		END;
		
	    });
#	    }
#	    else {
#		$db_query = $self->{'dbh'}->prepare(q{
#		    BEGIN 
#			:nextLig := tlakanen.ProductionName.NextLigationName(:cl_id, :vec_id);
#		    END;
#		    
#		});
		
		
#	    }
	    my $db_answer;
	    my $ligation_name;
	    $db_query->bind_param(":cl_id", $cl_id);
	    $db_query->bind_param(":vec_id", $vec_id);
	    $db_query->bind_param_inout(":nextLig", \$ligation_name, 64);
	    $db_query->execute;
	    
	    print "$ligation_name := gsc.ProductionName.NextLigationName($cl_id, $vec_id)\n";
	    if(defined $ligation_name) {
		return $ligation_name;
	    }
	    #######################################
	    else {
		
	    }

	    $self->{'Error'} = "$pkg: GetNextLigation() -> Could not get next Ligation name.";
	}
	else {
	    $self->{'Error'} = "$pkg: GetNextLigation() -> Could not find cl_id for fra_id = $fra_id.";
	}
    }
    else {
	$self->{'Error'} = "$pkg: GetNextLigation() -> Could not find vec_id for vl_id = $vl_id.";
    }

    return 0;
    
} #GetNextLigation

sub GetNextProjectId {

    my ($self) = @_;
    my $sql = "select project_seq.nextval from dual";
    my $project_id = Query( $self ->{'dbh'}, $sql);
    if($project_id) {
	return $project_id;
    }
    $self->{'Error'} = "$pkg: GetNextProjectId()";

    return 0;
 
} #GetNextProjectId


sub GetNextCgId {

    my ($self) = @_;
    my $sql = "select cg_seq.nextval from dual";
    my $cg_id = Query( $self ->{'dbh'}, $sql);
    if($cg_id) {
	return $cg_id;
    }
    $self->{'Error'} = "$pkg: GetNextCgId()";

    return 0;
 
} #GetNextCgId

sub GetNextClId {

    my ($self) = @_;
    my $sql = "select cl_seq.nextval from dual";
    my $cl_id = Query( $self ->{'dbh'}, $sql);
    if($cl_id) {
	return $cl_id;
    }
    $self->{'Error'} = "$pkg: GetNextClId()";

    return 0;
 
} #GetNextClId

sub GetNextFraId {

    my ($self) = @_;
    my $sql = "select fra_seq.nextval from dual";
    my $fra_id = Query( $self ->{'dbh'}, $sql);
    if($fra_id) {
	return $fra_id;
    }
    $self->{'Error'} = "$pkg: GetNextFraId()";

    return 0;
 
} #GetNextFraId

sub GetNextLigId {

    my ($self) = @_;
    my $sql = "select lig_seq.nextval from dual";
    my $lig_id = Query( $self ->{'dbh'}, $sql);
    if($lig_id) {
	return $lig_id;
    }
    $self->{'Error'} = "$pkg: GetNextLigId()";

    return 0;
 
} #GetNextLigId



 

sub GetAvailableWellsInGrowthPlate {
    my ($self, $barcode) = @_;	
    my $result = $self -> GetAvailableInfoInGrowthPlate($barcode, 'well_name');
    return $result;
}

sub GetAvailableLocationsInGrowthPlate {
    my ($self, $barcode) = @_;	
    my $result = $self -> GetAvailableInfoInGrowthPlate($barcode, 'pl_id');
    return $result;
}



sub GetAvailableInfoInGrowthPlate {


   my ($self, $barcode, $info_type) = @_;	
   
   my $dbh = $self -> {'dbh'};
   my $schema = $self -> {'Schema'};
   
   my $sql = "select count(*) from clone_growths_pses where pse_pse_id in (select distinct pse_pse_id from pse_barcodes 
              where bs_barcode = '$barcode' and direction = 'out')";
   my $count_pl_id = Query($dbh, $sql);
   my $range;
   if($count_pl_id == 0) {
       $sql = "select pl_id from plate_locations where well_name = 'a01' and pt_pt_id = (select pt_id from plate_types where well_count = '96')";
       $range = '>=';
   }
   else {
       $sql = "select max(pl_pl_id) from clone_growths_pses where pse_pse_id in (select distinct pse_pse_id from pse_barcodes 
              where bs_barcode = '$barcode' and direction = 'out')";
       $range = '>';
   }

   my $max_pl_id = Query($dbh, $sql);


   if(defined $max_pl_id) {
       
       $sql = "select pl_id from plate_locations where well_name = 'h12' and pt_pt_id = (select pt_id from plate_types where well_count = '96')";
       my $well_h12 = Query($dbh, $sql);

       if($info_type eq 'pl_id') {
	   $sql = "select pl_id from plate_locations where pl_id ".$range." '$max_pl_id' and pl_id <= '$well_h12' order by pl_id";
       }
       else {
	   $sql = "select well_name from plate_locations where pl_id ".$range." '$max_pl_id' and pl_id <= '$well_h12' order by pl_id";
       }
       my $avail_locations = Lquery($dbh, $sql);
       
       if(defined $avail_locations->[0]) {
	   my @list;
	       @list = @{$avail_locations}[0 .. ($#{$avail_locations})];
	       @list = @{$avail_locations}[0 .. 19] if($#{$avail_locations} > 20);
	       return \@list;
       }
       
       $self->{'Error'} = "$pkg: GetAvailableInfoInGrowthPlate() -> Could not find available locations.";
   }
   else {
	$self->{'Error'} = "$pkg: GetAvailableInfoInGrowthPlate() -> Could not find max plate location";
   }	
   
   return 0;
   
} #GetAvailableInfoInGrowthPlate
sub GetFractionGelPositions {

    my ($self, $barcode)  = @_;


    return $FractionGelPositions;

}
sub GetGelPositions1 {

    my ($self, $barcode)  = @_;

    return $GelPositions1;

}
sub GetGelPositions2 {

    my ($self, $barcode)  = @_;

    return $GelPositions2;

}
sub GetGelPositions3 {

    my ($self, $barcode)  = @_;

    return $GelPositions3;

}


sub ChangeGelConfiguration {

    my ($conf) = @_;

    print "config = $conf\n";

}


sub GetProcessStepBarcodePrefix {

    my ($self, $ps_id) = @_;
    my $schema = $self->{'Schema'};
    my $sql = "select bp_barcode_prefix from process_steps where ps_id = '$ps_id'";
    my $result = Query($self->{'dbh'}, $sql);

    if($result) {
	return $result;
    }
    
    $self->{'Error'} = "$pkg: GetProcessStepBarcodePrefix() -> Could not find barcode prefix for ps_id = $ps_id.";
      
    return 0;

} #GetProcessStepBarcodePrefix

sub GetVlIdfromReagent {

    my ($self, $barcode) = @_;

    my $dbh = $self ->{'dbh'};
    my $schema = $self->{'Schema'};
   
    my $sql = "select vl_vl_id from reagent_vector_linearizations where rn_reagent_name = (select rn_reagent_name from 
               reagent_informations where bs_barcode = '$barcode')";
    my $vl_id = Query($dbh, $sql);

    if(defined $vl_id) {
	return $vl_id;
    }
    return 0;
} #GetVlIdfromReagent

############################################################################################
#                                                                                          #
#                                     Insert Subrotines                                    #
#                                                                                          #
############################################################################################

sub InsertNewProject {

    my ($self, $clo_id, $purpose, $target, $priority, $pse_id, $project_name) = @_;

    my $status = 'shotgun_start';

    my $project_id = $self -> GetNextProjectId;
    return 0 if(!$project_id);
    
    if(! defined $project_name) {
	$project_name = $self -> GetCloneNameFromCloId($clo_id);
    }

    if(!$project_name) {
	$self->{'Error'} = "$pkg: InsertNewProject -> project name not defined.";
	return 0 ;
    }
    #project_id, purpose, target, priority, project_name, pp_purpose
    #my $result =  $self ->{'InsertProjects'}->xSql($project_id, $purpose, $target, $priority, $clone_name, $status);
    
    my $result = GSC::Project->create(project_id => $project_id, 
				      purpose => $purpose, 
				      target => $target, 
				      priority => $priority, 
				      name => $project_name, 
				      project_status => $status, 
				      pse_id => $pse_id);


    if($result) {
	$result = $self -> InsertClonesProjects($clo_id, $project_id);
	if($result) {
	    $result = $self -> InsertProjectStatusHistory($project_id, $status);

	    if($result) {
		return $project_id;
	    }
	    else {
		$self->{'Error'} = "$pkg: InsertNewProject() -> Could not insert into project_status_histories.";
		return 0;
	    }
	}
	else {
	    $self->{'Error'} = "$pkg: InsertNewProject() -> Failed insert project $project_id clone $clo_id";
	    return 0;
	}
    }

    $self->{'Error'} = "$pkg: InsertNewProject() -> $project_id, $clo_id, $purpose, $target, $priority";

    return 0;

}

sub InsertProjectStatusHistory {

    my ($self, $project_id, $status) = @_;

    #my $result =  $self ->{'InsertProjectStatusHistory'}->xSql($project_id, $status);

    my $result = GSC::ProjectStatusHistory->create(project_id => $project_id, 
						   project_status => $status, 
						   status_date =>  App::Time->now);
    
    if($result) {
	return $result;
    }
    
    $self->{'Error'} = "$pkg: InsertProjectStatusHistory() -> $project_id, $status";

    return 0;
} #InsertProjectStatusHistory

sub InsertClonesProjects {

    my ($self, $clo_id, $project_id) = @_;

#    my $result =  $self ->{'InsertClonesProjects'}->xSql($clo_id, $project_id);
    my $result =  GSC::CloneProject->create(clo_id => $clo_id, 
					    project_id => $project_id);
    if($result) {
	return $result;
    }
    
    $self->{'Error'} = "$pkg: InsertClonesProjects() -> $clo_id, $project_id";

    return 0;
} #InsertClonesProjects

########################################
# Insert cg_id into clone_growths_pses #
########################################
sub InsertProjectsPses{

    my ($self, $project_id, $new_pse_id) = @_;

    #my $result =  $self ->{'InsertProjectsPses'}->xSql($project_id, $new_pse_id);
    my $result = GSC::ProjectPSE->create(project_id => $project_id, 
					 pse_id => $new_pse_id);
    
    if($result) {
	return $result;
    }
    
    $self->{'Error'} = "$pkg: InsertProjectPses() -> $project_id, $new_pse_id";

    return 0;
} #InsertProjectsPses
 


########################################
# Insert cg_id into clone_growths_pses #
########################################
#sub InsertCloneGrowthsPses{

#   my ($self, $cg_id, $new_pse_id, $pl_id) = @_;

#   my $result =  $self ->{'InsertCloneGrowthsPses'}->xSql($cg_id, $new_pse_id, $pl_id);
#   if($result) {
#	return $result;
#   }
#   
#   $self->{'Error'} = "$pkg: InsertCloneGrowthsPses() -> $cg_id, $new_pse_id, $pl_id";
#
#   return 0;
# #InsertCloneGrowthsPses


 

#####################################
# Insert a new clone_growths record #
#####################################
sub InsertCloneGrowths {

    my ($self, $dna_id, $growth_ext, $clo_id, $location, $cg_cg_id, $purpose, $pse_id, $dl_id) = @_;

    my $parent_id = $clo_id;

    # insert new clone growth -> cg_id, growth_ext, clo_clo_id, location_library_core, cg_cg_id, purpose
#    my $result = $self->{'InsertCloneGrowths'}->xSql($cg_id, $growth_ext, $clo_id, 'unknown', $cg_cg_id, $purpose);

    
    my $result = GSC::CloneGrowth->create(dna_id => $dna_id, 
					  growth_ext => $growth_ext, 
					  location_library_core => 'unknown', 
					  purpose => $purpose,
					  parent_dna_id => $parent_id,
					  pse_id => $pse_id,
					  dl_id => $dl_id,
					  obsolete_cg_id=>$cg_cg_id
					  );
    if($result) {
	return $result;
    }

    $self->{'Error'} = "$pkg: InsertCloneGrowths() -> $dna_id, $growth_ext, $clo_id, $location, $cg_cg_id";
    return 0;

} #InsertCloneGrowths

###############################################
# Insert a new clone_growths_libraries record #
###############################################
#sub InsertCloneGrowthsLibraries {

#    my ($self, $cg_id, $cl_id) = @_;

#    my $result = $self->{'InsertCloneGrowthsLibraries'}->xSql($cg_id, $cl_id);
#    if($result) {
#	return $result;
#    }

#    $self->{'Error'} = "$pkg: InsertCloneGrowthsLibraries() -> $cg_id, $cl_id";
#    return 0;

#} #InsertCloneGrowthsLibraries


#######################################
# Insert a new clone_libraries record #
#######################################
sub InsertCloneLibraries {

    my ($self, $cl_id, $library_number, $parent_id, $pse_id) = @_;

    # insert new clone library
#    my $result = $self->{'InsertCloneLibraries'}->xSql($cl_id, $library_number);


    my $result = GSC::CloneLibrary->create(cl_id => $cl_id, 
					   library_number => $library_number, 
					   parent_dna_id => $parent_id, 
					   pse_id => $pse_id);
    if($result) {
	return $result;
    }



    $self->{'Error'} = "$pkg: InsertCloneLibraries() -> $cl_id, $library_number";
    return 0;

} #InsertCloneLibraries


##########################################
# Insert cl_id into clone_libraries_pses #
##########################################
#sub InsertCloneLibrariesPses{

#    my ($self, $cl_id, $new_pse_id, $lane_number) = @_;

#    my $result =  $self ->{'InsertCloneLibrariesPses'}->xSql($cl_id, $new_pse_id, $lane_number);
#    if($result) {
#	return $result;
#    }
#    
#    $self->{'Error'} = "$pkg: InsertCloneLibrariesPses() -> $cl_id, $new_pse_id, $lane_number";

#    return 0;
#} #InsertCloneLibrariesPses
 

#################################
# Insert a new fractions record #
#################################
sub InsertFractions {

    my ($self, $fra_id, $fraction_name, $cl_id, $min, $max, $pse_id) = @_;

    # insert new  library
    #my $result = $self->{'InsertFractions'}->xSql($fra_id, $fraction_name, 0, $cl_id, $min, $max);

    my $result = GSC::Fraction->create(fra_id => $fra_id, 
				       fraction_name => $fraction_name,
				       fraction_size => 0, 
				       min_base_length => $min, 
				       max_base_length => $max, 
				       parent_dna_id => $cl_id, 
				       pse_id => $pse_id);
    

    if($result) {
	return $result;
    }

    $self->{'Error'} = "$pkg: InsertFractions() -> Could not insert fractions where $fra_id, $fraction_name, $cl_id, $min, $max.";
    return 0;

} #InsertFractions


##########################################
# Insert fra_id into fractions_pses #
##########################################
#sub InsertFractionsPses{

#    my ($self, $fra_id, $new_pse_id, $lane_number) = @_;

#    my $result =  $self ->{'InsertFractionsPses'}->xSql($fra_id, $new_pse_id, $lane_number);
#    if($result) {
#	return $result;
#    }
    
#    $self->{'Error'} = "$pkg: InsertFractionsPses() -> $fra_id, $new_pse_id, $lane_number";

#    return 0;
#} #InsertFractionsPses
 

#################################
# Insert a new ligations record #
#################################
sub InsertLigations {

    my ($self, $lig_id, $ligation_name, $vl_id, $fra_id, $pse_id) = @_;

    # insert new  library lig_id, ligation_name, vl_vl_id, fra_fra_id, fraction_volume_ligated
    #my $result = $self->{'InsertLigations'}->xSql($lig_id, $ligation_name, $vl_id, $fra_id, 0);
    print "lig_id = $lig_id, ligation_name = $ligation_name, vl_id = $vl_id, fra_id = $fra_id, pse_id = $pse_id\n";

    my $result = GSC::Ligation->create(dna_id => $lig_id, 
				       vl_id => $vl_id, 
				       fraction_volume_ligated => 0,
				       parent_dna_id => $fra_id, 
				       pse_id => $pse_id);
    if($result) {
	return $result;
    }

    $self->{'Error'} = "$pkg: InsertLigations() -> $lig_id, $ligation_name, $vl_id, $fra_id";

    return 0;

} #InsertLigations




#####################################
# Insert lig_id into dna_pse #
#####################################
#sub InsertLigationsPses{

#    my ($self, $lig_id, $new_pse_id, $lane_number) = @_;

#    my $result =  $self ->{'InsertLigationsPses'}->xSql($lig_id, $new_pse_id, $lane_number);
#    if($result) {
#	return $result;
#    }
    
#    $self->{'Error'} = "$pkg: InsertLigationsPses() -> $lig_id, $new_pse_id, $lane_number";

#    return 0;
#} #InsertLigationsPses
 

#####################################
# Insert lig_id into dna_pse #
#####################################
#sub InsertSubclonesPses{

#    my ($self, $sub_id, $new_pse_id, $lane_number, $pl_id) = @_;

#    my $result =  $self ->{'InsertSubclonesPses'}->xSql($sub_id, $new_pse_id, $lane_number, $pl_id);
#    if($result) {
#	return $result;
#    }
    
#    $self->{'Error'} = "$pkg: InsertSubclonesPses() -> $sub_id, $new_pse_id, $lane_number, $pl_id";

#    return 0;
#} #InsertSubclonesPses
 

############################################################################################
#                                                                                          #
#                                     Update Subrotines                                    #
#                                                                                          #
############################################################################################

sub  UpdateProject {
    
    my ($self, $project_id, $purpose, $target, $priority) = @_;
    
#    my $sql = "update projects set pp_purpose = '$purpose', priority = '$priority', target = '$target' where project_id = '$project_id'";
#    my $result = Insert($self->{'dbh'}, $sql);
    
    my $proj = GSC::Project->get($project_id)->set(purpose  => $purpose,
						   priority => $priority,
						   target   => $target,
						   );
    

    return 1 if(defined $proj);
    
    $self->{'Error'} = "$pkg: UpdateProjectPurpose() -> Could not update project.";
    
    return 0;
}
	

 
sub  UpdateCloneLibrarySubId {
    
    my ($self, $cl_id, $sub_id) = @_;
    
#    my $sql = "update clone_libraries set sub_sub_id = '$sub_id' where cl_id = '$cl_id'";
#    my $result = Insert($self->{'dbh'}, $sql);
    my $result = GSC::CloneLibrary->get($cl_id)->set(sub_id => $sub_id
						     );

    if(defined $result) {
	return $result;
    }

    $self->{'Error'} = "$pkg: UpdateCloneLibrariesSubId -> Could not update cl_id  $cl_id with sub_id = $sub_id.";

    return 0;

} #UpdateCloneLibrarySubId

sub  UpdateLigation {
    
    my ($self, $lig_id, $titer) = @_;

#    my $sql = "update ligations set titer = '$titer' where lig_id = '$lig_id'";
#    my $result = Insert($self->{'dbh'}, $sql);

    my $lig = GSC::Ligation->get($lig_id);
    my $result = $lig->set(titer => $titer);
    
    if(defined $result) {
	return $result;
    }

    $self->{'Error'} = "$pkg: UpdateLigation -> Could not update ligation $lig_id with titer = $titer.";

    return 0;

} #UpdateLigation



sub UpdateSetAssignPse {
    
    my ($self, $ps_id, $cg_id) = @_;
    my $schema = $self->{'Schema'};
    my $sql = "select pse_id from process_step_executions where psesta_pse_status = 'inprogress' and pse_id in 
               (select pse_pse_id from  clone_growths_pses where cg_cg_id = '$cg_id') and ps_ps_id in 
               (select ps_id from  process_steps where pro_process_to in 
               (select pro_process from process_steps where ps_id = '$ps_id'))";
    my $pse_id = Query($self->{'dbh'}, $sql);
    
    if($pse_id) {
	my $update_status = 'completed';
	my $update_result = 'successful';
	my $result =  $self->{'CoreSql'}->Process('UpdatePse', $update_status, $update_result, $pse_id);
	return ($self->GetCoreError) if(!$result);

	return 1;

    }
    
    $self->{'Error'} = "$pkg: UpdateSetAssignPse -> Could not find pse for ps_id = $ps_id and cg_id = $cg_id.";
    
    return 0;
} #UpdateSetAssignPse
  
############################################################################################
#                                                                                          #
#                                     Utilty Subrotines                                    #
#                                                                                          #
############################################################################################

   
sub PrintCloneLabel {
    my ($self, $pse_id) = @_;
    
    my ($dp) = GSC::DNAPSE->get(pse_id=>$pse_id);
    if (!defined $dp) {
	$self->{'Error'} = "$pkg: PrintCloneLabel() -> No dnapse for $pse_id";
	return 0;
    }

    my $dna = GSC::DNA->get($dp->dna_id);
    my $clone = $dna->dna_name;
    
    #`lplabel -P  $self->{'printer'} -l $clone`;
    App::Print->print
        (
         protocol => 'barcode',
         printer => $self->{'printer'},
         type => 'label',
         data => [ $clone  ]
         );
   
    return 1;
} #PrintCloneLabel

#########################
# Prints text passed in #
#########################
sub PrintText {
    
    my ($self, $text) = @_;
    my $file = '/tmp/printfile';
    
    `rm $file` if(-e $file);
    `echo '$text' > $file`;

    # print no header, margins top:bottom:left:right, postscript level 1, word wrap, filname
    `enscript -B --margins=50:50:100:100 --ps-level=1 --word-wrap $file`;


} #PrintText



#-----------------------------------
# Set emacs perl mode for this file
#
# Local Variables:
# mode:perl
# End:
#
#-----------------------------------


