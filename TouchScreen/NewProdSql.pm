# -*-Perl-*-

##############################################
# Copyright (C) 2001 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

package TouchScreen::NewProdSql;

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


our @ISA = qw (Exporter AutoLoader TouchScreen::CoreSql);
our @EXPORT = qw ( );

my $pkg = __PACKAGE__;

#########################################################
# Create a new instance of the NewProdSql code so that you #
# can easily use more than one data base schema         #
#########################################################
sub new {

    # Input
    my ($class, $dbh, $schema) = @_;
    
    my $self;

    $self = $class->SUPER::new($dbh, $schema);
    bless $self, $class;

    $self->{'dbh'} = $dbh;
    $self->{'Schema'} = $schema;
    $self->{'Error'} = '';

    $self->{'CoreSql'} = TouchScreen::CoreSql->new($dbh, $schema);

    $self->{'GetAvailAgarPlate'} = LoadSql($dbh, qq/select distinct clone_name, library_number, ligation_name, pse.pse_id, priority
					       from projects, clones_projects cp, clones, clone_growths cg, clone_growths_libraries cgl, 
					       clone_libraries cl, fractions fr, ligations lg,
					       dna_pse lgx,
					       pse_barcodes barx, process_step_executions pse where
					       project_id = project_project_id and
					       cp.clo_clo_id = cg.clo_clo_id and 
					       cp.clo_clo_id = clo_id and
					       cg.cg_id = cgl.cg_cg_id and
					       cgl.cl_cl_id = cl.cl_id and
					       lgx.dna_id = lg.lig_id and
					       fr.fra_id = lg.fra_fra_id and
					       fr.cl_cl_id = cl.cl_id and
					       pse.pse_id = lgx.pse_id and
					       barx.pse_pse_id = pse.pse_id and
					       pse.psesta_pse_status = ? and
					       barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
					       (select ps_id from process_steps where pro_process_to in
						(select pro_process from process_steps where ps_id = ?) and      
						purpose =  ?)/, 'ListOfList');
    $self->{'GetAvailAgarPlatePSE'} = LoadSql($dbh, qq/select distinct clone_name, library_number, ligation_name, pse.pse_id, priority
					       from projects, clones_projects cp, clones, clone_growths cg, clone_growths_libraries cgl, 
					       clone_libraries cl, fractions fr, ligations lg,
					       dna_pse lgx,
					       pse_barcodes barx, process_step_executions pse where
					       project_id = project_project_id and
					       cp.clo_clo_id = cg.clo_clo_id and 
					       cp.clo_clo_id = clo_id and
					       cg.cg_id = cgl.cg_cg_id and
					       cgl.cl_cl_id = cl.cl_id and
					       lgx.dna_id = lg.lig_id and
					       fr.fra_id = lg.fra_fra_id and
					       fr.cl_cl_id = cl.cl_id and
					       pse.pse_id = lgx.pse_id and
					       barx.pse_pse_id = pse.pse_id and
					       pse.pse_id = ?/, 'ListOfList');

    $self->{'GetAvailAgarPlateNoPriority'} = LoadSql($dbh, qq/select distinct clone_name, library_number, ligation_name, pse.pse_id
							 from clones, clone_growths cg, clone_growths_libraries cgl, 
							 clone_libraries cl, fractions fr, ligations lg,
							 dna_pse lgx,
							 pse_barcodes barx, process_step_executions pse where
							 cg.clo_clo_id = clo_id and
							 cg.cg_id = cgl.cg_cg_id and
							 cgl.cl_cl_id = cl.cl_id and
							 lgx.dna_id = lg.lig_id and
							 fr.fra_id = lg.fra_fra_id and
							 fr.cl_cl_id = cl.cl_id and
							 pse.pse_id = lgx.pse_id and
							 barx.pse_pse_id = pse.pse_id and
							 pse.psesta_pse_status = ? and
							 barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
							 (select ps_id from process_steps where pro_process_to in
							  (select pro_process from process_steps where ps_id = ?) and      
							  purpose =  ?)/, 'ListOfList');
    $self->{'GetAvailAgarPlateNoPriorityPSE'} = LoadSql($dbh, qq/select distinct clone_name, library_number, ligation_name, pse.pse_id
							 from clones, clone_growths cg, clone_growths_libraries cgl, 
							 clone_libraries cl, fractions fr, ligations lg,
							 dna_pse lgx,
							 pse_barcodes barx, process_step_executions pse where
							 cg.clo_clo_id = clo_id and
							 cg.cg_id = cgl.cg_cg_id and
							 cgl.cl_cl_id = cl.cl_id and
							 lgx.dna_id = lg.lig_id and
							 fr.fra_id = lg.fra_fra_id and
							 fr.cl_cl_id = cl.cl_id and
							 pse.pse_id = lgx.pse_id and
							 barx.pse_pse_id = pse.pse_id and
							 pse.pse_id = ?/, 'ListOfList');

    $self -> {'GetAvailSubclone'} = LoadSql($dbh,  "select distinct cl.library_number, lig.ligation_name, ar.archive_number, pse.pse_id from 
               clone_libraries cl,
               fractions fra, ligations lig, pse_barcodes barx, 
               process_step_executions pse, subclones sc,
               subclones_pses subx, archives ar
               where cl.cl_id = fra.cl_cl_id and 
                   fra.fra_id = lig.fra_fra_id and 
                   barx.pse_pse_id = pse.pse_id and
                   pse.pse_id = subx.pse_pse_id and 
                   sc.arc_arc_id = ar.arc_id and
                   sc.lig_lig_id = lig.lig_id and 
                   sc.sub_id = subx.sub_sub_id and
                   pse.psesta_pse_status = ? and 
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = ?)", 'ListOfList');

    
    $self -> {'GetAvailArchive'} = LoadSql($dbh,  "select distinct cl.library_number, lig.ligation_name, ar.archive_number, pse.pse_id from 
               clone_libraries cl,
               fractions fra, ligations lig, pse_barcodes barx, 
               process_step_executions pse, subclones sc,
               archives_pses arx, archives ar
               where cl.cl_id = fra.cl_cl_id and 
                   fra.fra_id = lig.fra_fra_id and 
                   barx.pse_pse_id = pse.pse_id and
                   pse.pse_id = arx.pse_pse_id and 
                   arx.arc_arc_id = ar.arc_id and
                   sc.arc_arc_id = ar.arc_id and 
                   sc.lig_lig_id = lig.lig_id and 
                   pse.psesta_pse_status = ? and 
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where  pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = ?)", 'ListOfList');
						
    $self->{'GetAvailSeqDna'} = LoadSql($dbh, "select distinct cl.library_number, lig.ligation_name, an.archive_number, pse.pse_id from 
               clone_libraries cl, fractions fra, ligations lig, subclones sub, 
               archives an, pse_barcodes barx, sequenced_dnas sd, seq_dna_pses sdx,
               process_step_executions pse
               where 
                  cl.cl_id = fra.cl_cl_id and fra.fra_id = lig.fra_fra_id and 
                  lig.lig_id = sub.lig_lig_id and an.arc_id = sub.arc_arc_id and 
                  sub.sub_id = sd.sub_sub_id and sd.seqdna_id = sdx.seqdna_seqdna_id and
                  barx.pse_pse_id = sdx.pse_pse_id and
                  barx.pse_pse_id = pse.pse_id and
                  pse.psesta_pse_status = ? and 
                  barx.bs_barcode = ? and 
                  barx.direction = ? and 
                  pse.ps_ps_id in 
                      (select ps_id from process_steps where  pro_process_to in
                      (select pro_process from process_steps where ps_id = ?) and      
                      purpose = ?)", 'ListOfList');
    
    $self -> {'GetAvailSeqDnaResuspendInput'} = LoadSql($dbh, qq/select  x.library_number, x.ligation_name, x.archive_number,  x.pse_id, count(pb2.psebar_id) 
							from pse_barcodes pb2, (
										select  distinct cl.library_number, lig.ligation_name, an.archive_number, pse.pse_id
										from
										clone_libraries cl 
										join  fractions fra on fra.cl_cl_id = cl.cl_id 
										join ligations lig on lig.fra_fra_id = fra.fra_id
										join subclones sub on sub.lig_lig_id = lig.lig_id
										join sequenced_dnas sd on sd.sub_sub_id = sub.sub_id
										join dna_pse dp on dp.dna_id = sd.seqdna_id
										join archives an on an.arc_id = sub.arc_arc_id
										join process_step_executions pse on pse.pse_id = dp.pse_id
										join pse_barcodes barx on barx.pse_pse_id = pse.pse_id 
										where
										pse.psesta_pse_status = ? and
										barx.bs_barcode = ? and
										barx.direction = ? and
										pse.ps_ps_id in
										(select ps_id from process_steps where  pro_process_to in
										 (select pro_process from process_steps where ps_id = ?) and
										 purpose = ?)
										) x
							where 
							pb2.pse_pse_id (+) = x.pse_id 
							group by  x.library_number, x.ligation_name, x.archive_number, x.pse_id 
							having count(pb2.psebar_id) = 1
							/, 'ListOfList');
$self -> {'InsertArchives'} = LoadSql($dbh, "insert into archives 
	    (archive_number, available, gro_group_name, arc_id, ap_purpose)
	    values (?, ?, ?, ?, ?)");
#    $self->{'InsertSubclones'} = LoadSql($dbh, "insert into subclones
#		            (subclone_name, lig_lig_id, sub_id, arc_arc_id) 
#		            values (?, ?, ?, ?)");
#    $self->{'InsertSequencedDnas'} = LoadSql($dbh, "insert into sequenced_dnas
#		    (sub_sub_id, pri_pri_id, dc_dc_id, enz_enz_id, seqdna_id) 
#		    values (?, ?, ?, ?, ?)");
    
    $self->{'GetArchiveNumber'} = LoadSql($dbh, "select archive_number from archives where arc_id = ?", 'Single');
    $self->{'GetWellCount'} = LoadSql($dbh, "select well_count from plate_types where pt_id = ?", 'Single');
 
    $self->{'GetLigIdFromPse'} = LoadSql($dbh,"select dna_id from dna_pse where pse_id = ?", 'Single');    

    $self -> {'GetSectorName'} = LoadSql($dbh, "select sector_name from sectors where sec_id = ?", 'Single');
    $self->{'GetPlId'} = LoadSql($dbh, "select pl_id from plate_locations where well_name = ? and 
                                    sec_sec_id = ? and pt_pt_id = ?", 'Single');
    
#    $self -> {'InsertSubclonesPses'} = LoadSql($dbh, "insert into subclones_pses
#	    (pse_pse_id, sub_sub_id, pl_pl_id) 
#	    values (?, ?, ?)");
    $self->{'GetArcIdFromPseInSubPses'} = LoadSql($dbh, "select distinct arc_arc_id from subclones, subclones_pses where sub_id = sub_sub_id
                                                             and pse_pse_id = ?", 'Single');

#    $self->{'InsertLigationsPses'} = LoadSql($dbh,"insert into ligations_pses (lig_lig_id, pse_pse_id, gel_lane) values (?, ?, ?)");
#    $self -> {'InsertArchivesPses'} = LoadSql($dbh, "insert into archives_pses
#	    (pse_pse_id, arc_arc_id) 
#	    values (?, ?)");
    
#    $self->{'InsertSeqDnaPses'} = LoadSql($dbh,  "insert into seq_dna_pses
#	    (pse_pse_id, seqdna_seqdna_id, pl_pl_id) 
#	    values (?, ?, ?)");



$self->{'GetAvailableQuadsPses'} = LoadSql($dbh, qq/select distinct UPPER(sector_name), dp.pse_id 
					   from sectors s, process_step_executions pse, dna_location dl, dna_pse dp
					   where pse.pse_id in (select pse_pse_id from pse_barcodes 
								where bs_barcode = ? and
								direction = 'out')
					   and dp.pse_id = pse.pse_id and dp.dl_id = dl.dl_id and dl.sec_id = s.sec_id 
					   group by sector_name, dp.pse_id
					   having count(dp.dna_id) = 96
					   order by UPPER(sector_name)/);
#LoadSql($dbh, "select distinct UPPER(sector_name), arx.pse_pse_id from sectors, archives, 
#               archives_pses arx, process_step_executions pse,
#               plate_locations, subclones_pses scx, subclones sc, plate_types
#               where arx.pse_pse_id in (select pse_pse_id from pse_barcodes where bs_barcode = ? and
#               direction = 'in')  and arx.arc_arc_id = arc_id and arc_id = sc.arc_arc_id and pse.pse_id = arx.pse_pse_id and
#               psesta_pse_status = 'inprogress' and
#               sub_sub_id = sub_id and pl_pl_id = pl_id and sec_sec_id = sec_id and pt_pt_id = pt_id and well_count = '384' order by UPPER(sector_name)", 'ListOfList');
#    $self -> {'GetSubIdPlIdFromArchivePse'} = LoadSql($dbh, "select distinct sub_sub_id, well_name, pl_id 
#               from pse_barcodes pbx, subclones_pses scx, subclones sc, plate_locations pl
#               where pbx.bs_barcode = ? and pbx.direction = 'out' and 
#               pl.pl_id = scx.pl_pl_id and 
#               pbx.pse_pse_id = scx.pse_pse_id and scx.sub_sub_id = sc.sub_id and
#               sc.arc_arc_id = (select distinct arc_arc_id from archives_pses where pse_pse_id = ?)", 'ListOfList');

$self -> {'GetSubIdPlIdFromArchivePse'} = LoadSql($dbh, qq/select distinct sub_sub_id, well_name, pl_id 
						  from pse_barcodes pbx, subclones_pses scx, subclones sc, plate_locations pl, sectors
						  where pbx.bs_barcode = ? and pbx.direction = 'out' and
						  pl.pl_id = scx.pl_pl_id and UPPER(sector_name) = ? and sec_sec_id = sec_id and
						  pbx.pse_pse_id = scx.pse_pse_id and scx.sub_sub_id = sc.sub_id/, 'ListOfList');

$self -> {'GetSubIdPlIdFromSubclonePse'} = LoadSql($dbh, qq/select  distinct dp.dna_id, dl.location_name, dl.dl_id  
                                                   from pse_barcodes pbx 
                                                   join dna_pse dp on dp.pse_id = pbx.pse_pse_id
                                                   join dna_location dl on dl.dl_id = dp.dl_id 
                                                   where 
                                                   pbx.bs_barcode = ? and
                                                   dp.pse_id  = ?/, 'ListOfList');
    
    $self -> {'GetSeqDnaIdPlIdFromSeqDnaPse'} = LoadSql($dbh, qq/select distinct dp.dna_id,  dl.location_name, dl.dl_id  
                                                    from pse_barcodes pbx
                                                    join dna_pse dp on dp.pse_id= pbx.pse_pse_id
                                                    join dna_location dl on dl.dl_id = dp.dl_id
                                                    where pbx.bs_barcode = ? and 
                                                    dp.pse_id = ?/);

#"select distinct seqdna_seqdna_id, well_name, pl_id  
#               from pse_barcodes pbx, seq_dna_pses scx, plate_locations pl
#               where pbx.bs_barcode = ? and 
#               pl.pl_id = scx.pl_pl_id and 
#               pbx.pse_pse_id = scx.pse_pse_id and 
#               seqdna_seqdna_id in (select seqdna_seqdna_id from seq_dna_pses where pse_pse_id = ?)", 'ListOfList');

    
     $self->{'GetArchiveFromPse'} = LoadSql($dbh,  "select distinct sc.arc_arc_id from subclones_pses sbl, 
               subclones sc where sbl.pse_pse_id = ? and 
               sbl.sub_sub_id = sc.sub_id", 'Single');
    
     $self -> {'GetArchivePurposeFromBarcode'} = LoadSql($dbh, "select distinct ap_purpose from 
                                             archives, subclones, subclones_pses, pse_barcodes, process_step_executions where pse_id = pse_barcodes.pse_pse_id and
                                                pse_id = subclones_pses.pse_pse_id and sub_id = sub_sub_id and arc_id = arc_arc_id
                                                and direction = 'out' and bs_barcode = ?", 'Single');

    $self->{'CheckClonePurpose'} = LoadSql($dbh, "select distinct ct_clone_type from clones, clone_growths, clone_growths_libraries cgl, fractions fr, ligations
                                                      where 
                                                      clo_id = clo_clo_id and
                                                      cg_id = cgl.cg_cg_id and
                                                      cgl.cl_cl_id  = fr.cl_cl_id and
                                                      fra_id = fra_fra_id and
                                                      lig_id = (select lgx.dna_id from dna_pse lgx where lgx.pse_id in (select pse_pse_id 
                                                          from pse_barcodes where bs_barcode = ? and direction = 'out'))", 'Single');

    $self->{'GetProjectTargetFromAgarPlate'} = LoadSql($dbh,  "select distinct project_id, projects.target from pse_barcodes, ligations, dna_pse, 
                                    fractions, clone_growths, clone_growths_libraries, clones, projects , clones_projects
                                    where pse_barcodes.pse_pse_id = dna_pse.pse_id and
                                    dna_pse.dna_id = lig_id and fra_id = fra_fra_id and fractions.cl_cl_id = clone_growths_libraries.cl_cl_id and 
                                    cg_id = clone_growths_libraries.cg_cg_id and clone_growths.clo_clo_id = clo_id and 
                                    clones_projects.clo_clo_id = clo_id and project_project_id = project_id 
                                    and projects.name = clones.clone_name and bs_barcode = ? and direction = 'out'", 'ListOfList'); 
    
    $self->{'CheckIfProjectOpen'} = LoadSql($dbh, "select count(*) from process_step_executions pse, ligations, dna_pse, 
                                    fractions, clone_growths, clone_growths_libraries, clones, projects, clones_projects where 
                                    pse.pse_id = dna_pse.pse_id and
                                    dna_pse.dna_id = lig_id and fra_id = fra_fra_id and fractions.cl_cl_id = clone_growths_libraries.cl_cl_id and 
                                    cg_id = clone_growths_libraries.cg_cg_id and clone_growths.clo_clo_id = clo_id and 
                                    clones_projects.clo_clo_id = clo_id and project_project_id = project_id and project_id = ? and ps_ps_id = ? and 
                                    psesta_pse_status = 'inprogress'", 'Single');
    
    $self->{'GetLigIdFromBarcode'} = LoadSql($dbh, "select distinct dna_id from dna_pse lgx, 
                                                  pse_barcodes where lgx.pse_id = pse_barcodes.pse_pse_id  and bs_barcode = ? and
                                                  direction = 'out'", 'Single');
    
    $self->{'CheckQcStatusForLigation'} = LoadSql($dbh, "select data_value, pse_pse_id from process_step_outputs, pse_data_outputs
                                                  where
                                                  pso_id = pso_pso_id and output_description = 'pick qc' and
                                                  pse_pse_id in (select max(pse.pse_id) from dna_pse lgx, process_step_executions pse,
                                                  process_steps where pse.ps_ps_id = ps_id and lgx.pse_id = pse.pse_id 
                                                  and pro_process_to = 'confirm dilution' and dna_id = ?)", 'ListOfList');
    
    
    $self->{'GetNumbersPickedForLigation'} = LoadSql($dbh, "select count(*) from process_step_executions, process_steps, subclones_pses,
                                                             subclones
                                                             where pse_pse_id = pse_id and ps_ps_id = ps_id and lig_lig_id = ? and sub_sub_id = sub_id and
                                                             pro_process_to = 'pick' and
                                                             purpose = ? and output_device = ?   and psesta_pse_status in ('inprogress', 'completed')
                                                             and (pr_pse_result = 'successful' or pr_pse_result is NULL)", 'Single');

    $self->{'GetNumbersPickedForProject'} = LoadSql($dbh,"select distinct arc_id from 
                                                             ligations, fractions, clone_growths, clone_growths_libraries, 
                                                             clones_projects, subclones, archives
                                                             where project_project_id = ? and clones_projects.clo_clo_id = clone_growths.clo_clo_id and
                                                             lig_lig_id = lig_id and fra_id = fra_fra_id and fractions.cl_cl_id = clone_growths_libraries.cl_cl_id and
                                                             cg_id = clone_growths_libraries.cg_cg_id and arc_arc_id = arc_id and ap_purpose != 'qc'", 'List');

     $self->{'InsertReagentUsedPses'} = LoadSql($dbh,"insert into reagent_used_pses (RI_BS_BARCODE, pse_pse_id) values (?,?)");
  
     $self->{'GetBarocdeCreatePse'} = LoadSql($dbh,"select distinct pse_pse_id from pse_barcodes where bs_barcode = ? and direction = 'out'", 'List');
  
    $self -> {'GetAvailMiniPrep'} = LoadSql($dbh,  "select distinct cl.library_number, lig.ligation_name, ar.archive_number, pse.pse_id from 
               clone_libraries cl,
               fractions fra, ligations lig,
               process_step_executions pse, subclones sc,
               subclones_pses subx, archives ar
               where cl.cl_id = fra.cl_cl_id and 
                   fra.fra_id = lig.fra_fra_id and 
                   pse.pse_id = subx.pse_pse_id and 
                   sc.arc_arc_id = ar.arc_id and
                   sc.lig_lig_id = lig.lig_id and 
                   sc.sub_id = subx.sub_sub_id and
                   pse.psesta_pse_status = ? and 
                   pse.ps_ps_id in (select ps_id from process_steps where pro_process_to = ? and      
                                    purpose = ?) and 
                   subx.sub_sub_id in (select subx.sub_sub_id from subclones_pses subx, pse_barcodes barx where
                                       barx.bs_barcode = ? and 
                                       barx.direction = ? and 
                                       barx.pse_pse_id = subx.pse_pse_id)", 'ListOfList');

    $self->{'GetSubcloneLocations'} =  LoadSql($dbh,  "select distinct well_name, pse_id from 
                              process_step_executions pse, subclones sc,
                              subclones_pses subx, plate_locations
                              where 
                                  pse.pse_id = subx.pse_pse_id and 
                                  pse.psesta_pse_status = ? and 
                                  pl_id = pl_pl_id and
                                  pse.ps_ps_id in (select ps_id from process_steps where pro_process_to = ? and      
                                                    purpose = ?) and 
                                  subx.sub_sub_id in (select subx.sub_sub_id from subclones_pses subx, pse_barcodes barx where
                                                      barx.bs_barcode = ? and 
                                                      barx.direction = ? and 
                                                      barx.pse_pse_id = subx.pse_pse_id)", 'ListOfList');

    
   $self->{'GetAvailSubcloneGelCheck'} = LoadSql($dbh, "select distinct clone_name, library_number, subclone_name, pse.pse_id
               from 
	       clones clo, clone_growths cg, 
               clone_growths_libraries cgl,
	       clone_libraries cl,  
               fractions fr,
               ligations lg, 
               subclones, 
               subclones_pses subx,
               pse_barcodes barx, process_step_executions pse where
               clo.clo_id = cg.clo_clo_id and
               cgl.cg_cg_id = cg.cg_id and
               cgl.cl_cl_id = cl.cl_id and
               cl.cl_id = fr.cl_cl_id and
               lg.fra_fra_id = fr.fra_id and
               lg.lig_id = lig_lig_id and
               sub_id = subx.sub_sub_id and
               pse.pse_id = subx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               pse.psesta_pse_status = ? and
               pse.pr_pse_result = ? and 
               sub_id = (
                   select sub_sub_id from subclones_pses subx, pse_barcodes barx where 
                   barx.bs_barcode = ? and barx.direction = ? and subx.pse_pse_id = barx.pse_pse_id) 
               and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = ?)", 'ListOfList');

    $self->{'GetPsoDescription'} = LoadSql($dbh, "select OUTPUT_DESCRIPTION from process_step_outputs where pso_id = ?", 'Single');

    $self -> {'GetFosmidLigCloPrefix'} = LoadSql($dbh, 
						 qq/
						 select distinct lig_id, cp.clone_prefix from ligations l, fractions fr, clone_libraries cl, 
						 clone_growths_libraries cgl, clone_growths cg, clones, clone_prefixes cp
						 where 
						 clo_id = cg.clo_clo_id and
						 cg.cg_id = cgl.cg_cg_id and
						 cgl.cl_cl_id = cl.cl_id and
						 cl.cl_id = fr.cl_cl_id and
						 fr.fra_id = l.fra_fra_id and
						 clone_name like '%FOSMID%' and 
						 growth_ext = 'a' and
                                                 clones.ct_clone_type = 'fosmid library' and
						 library_number = '001' and
						 cp.clone_prefix = clones.clopre_clone_prefix and
						 cp.clone_prefix = ?/, );

    $self->{'GetAvailableQuadsArcPses'}  = LoadSql($dbh, qq/select arc_arc_id, pse.pse_id  from 
						   pse_barcodes pb, archives_pses arx, process_step_executions pse 
						   where bs_barcode = ? 
						   and direction = 'in' 
						   and psesta_pse_status = 'inprogress' 
						   and pse.pse_id = pb.pse_pse_id
						   and arx.pse_pse_id = pse.pse_id /);

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
# Destroy a NewProdSql session #
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

#  get all the pses, in order, that were sources for the dna
#  this is useful for steps that have priors that were converted to the 'no dna pse' or that went to a 1-pse-per-plate instead of 1-pse-per-quadrant model.  See ClaimArchiveInoc or something like that for an example.

sub dna_source_pses{
    my $self = shift;
    my $barcode = shift;
    
    my $bc= GSC::Barcode->get(barcode => $barcode);
    my %dp = map {$_->pse_id => 1} $bc->get_dna_pse;
    return sort keys %dp;
}


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


##########################################
#  main agar plate processing subroutine #
##########################################
sub GetAvailAgarPlate {

    my ($self, $barcode, $ps_id, $direction, $status, $purpose) = @_;
    my @pbs = GSC::PSEBarcode->get(barcode => $barcode, direction => $direction);
    my @pses = GSC::PSE->get(pse_id => \@pbs, pse_status => $status, ps_id => [GSC::ProcessStep->get(process_to => [ map { $_->process } GSC::ProcessStep->get(ps_id => $ps_id)])]);
    unless(@pses == 1) {
      $self->{'Error'} = "$pkg: GetAvailAgarPlate() -> $barcode, $ps_id, $direction, $status.";
      return 0;
    }
    my @pbos = GSC::PSEBarcode->get(barcode => $barcode, direction => 'out');
    unless(@pbos == 1) {
      $self->{'Error'} = "$pkg: GetAvailAgarPlate() -> $barcode, $ps_id, $direction, $status.";
      return 0;      
    }
    my $lol = $self->{'GetAvailAgarPlatePSE'} -> xSql($pbos[0]->pse_id);
    
    #my $lol = $self->{'GetAvailAgarPlate'} -> xSql($status, $barcode, $direction, $ps_id, $purpose);
    
    if(defined $lol->[0][0]) {
	#return ($lol->[0][0].' '.$lol->[0][1].' '.$lol->[0][2], [$lol->[0][3]], $lol->[0][4]);
	return ($lol->[0][0].' '.$lol->[0][1].' '.$lol->[0][2], [$pses[0]->pse_id], $lol->[0][4]);
    }
    else {
	#may not have a project, thus no priority so do this query
	#my $lol = $self->{'GetAvailAgarPlateNoPriority'} -> xSql($status, $barcode, $direction, $ps_id, $purpose);	
	my $lol = $self->{'GetAvailAgarPlateNoPriorityPSE'} -> xSql($pbos[0]->pse_id);
	if(defined $lol->[0][0]) {
	    #return ($lol->[0][0].' '.$lol->[0][1].' '.$lol->[0][2], [$lol->[0][3]], 0);
	    return ($lol->[0][0].' '.$lol->[0][1].' '.$lol->[0][2], [$pses[0]->pse_id], 0);
	}
	
    }

    $self->{'Error'} = "$pkg: GetAvailAgarPlate() -> $barcode, $ps_id, $direction, $status.";
    $self->{'Error'} = $self->{'Error'}." $DBI::errstr" if(defined $DBI::errstr);

    return 0;

} #GetAvailAgarPlate



##########################################
#  main agar plate processing subroutine #
##########################################
sub GetAvailPlasmidAgarPlateIn {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'in', 'inprogress', 'Plasmid Picking');
    
    return ($result, $pses);

} #GetAvailAgarPlate

sub GetAvailPlasmidAgarPlateToPick96Anything {

    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self->{'CoreSql'} -> GetAvailBarcodeInInprogress($barcode, $ps_id);
    $self -> {'WGS agar plate'} = 1;
    return ($result, $pses);

} #GetAvailPlasmidAgarPlateToPick96

##########################################
#  main agar plate processing subroutine #
##########################################
sub GetAvailPlasmidAgarPlateToPick96 {

    my ($self, $barcode, $ps_id) = @_;
    
    my $purpose = $self->{'CheckClonePurpose'} -> xSql($barcode);
    $purpose = 'genome' unless($purpose);

    if($purpose ne 'genome')  {
	my $project_info = $self->{'GetProjectTargetFromAgarPlate'} -> xSql($barcode);
	my $project_id = $project_info->[0][0];
	my $target = $project_info->[0][1];
	$self->{'MaxPlatesToPick'} = 0;
	$self->{'PlatesScanned'} = 0;
	$self->{'TargetMet'} = 0;
	$self->{'WGS agar plate'} = 0;
	
	if(defined $project_id) {
	    
	    my $lig_id = $self->{'GetLigIdFromBarcode'} -> xSql($barcode);
	    my $qc_info = $self->{'CheckQcStatusForLigation'} -> xSql($lig_id);
	    if($qc_info->[0][0] eq 'yes') {
		my $picked96 = $self->{'GetNumbersPickedForLigation'} -> xSql($lig_id, 'Plasmid Picking', '96 archive plate');
		if($picked96 == 0) {
		    $self->{'MaxPlatesToPick'} =  1;
		    my ($result, $pses) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'in', 'inprogress', 'Plasmid Picking');
		    return ($result, $pses);
		}		
		else {
		    $self->{'Error'} = "This agar plate does not need a 96 well plate picked for this ligation, already picked.";  
		    return 0;
		}
	    }
	    else {
		$self->{'Error'} = "This agar plate does not need a 96 well plate picked for this ligation.";  
		return 0;
	    }
	}
	
	$self->{'Error'} = "$pkg: GetAvailPlasmidAgarPlateToPick96() -> Could not find project for barcode = $barcode.";
    
    }
    else {
	my ($result, $pses) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'in', 'inprogress', 'Plasmid Picking');
	$self -> {'WGS agar plate'} = 1;
	return ($result, $pses);
    }
    return 0;
} #GetAvailPlasmidAgarPlateToPick96


##########################################
#  main agar plate processing subroutine #
##########################################
sub GetAvailPlasmidAgarPlateToPick384 {
    my ($self, $barcode, $ps_id) = @_;
    
    my $purpose = $self->{'CheckClonePurpose'} -> xSql($barcode);
    $purpose = 'genome' unless($purpose);

    if($purpose ne 'genome') {
	my $project_info = $self->{'GetProjectTargetFromAgarPlate'} -> xSql($barcode);
	my $project_id = $project_info->[0][0];
	my $target = $project_info->[0][1];
	$self->{'MaxPlatesToPick'} = 0;
	$self->{'PlatesScanned'} = 0;
	$self->{'TargetMet'} = 0;
	$self->{'WGS agar plate'} = 0;
	
	if(defined $project_id) {
	    my $picked_archives = $self->{'GetNumbersPickedForProject'} -> xSql($project_id);		    
	    $picked_archives = $#{$picked_archives}+1;

	    #my $picked_archives = ($self->{'GetNumbersPickedForProject'} -> xSql($project_id, 'Plasmid Picking', '384 archive plate')) / 96;		    
	    my $arcs2pick = ($target - $picked_archives);
	    if($arcs2pick > 0) {
		my $plates2pick = int($arcs2pick/4);
		my $remainder = ($arcs2pick % 4);
		
		# There never should be a remainder but incase there is round up
		if($remainder > 0) {
		    $plates2pick++;
		}
		
		$self->{'MaxPlatesToPick'} =  $plates2pick;
		
		my ($result, $pses) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'in', 'inprogress', 'Plasmid Picking');
		
		return ($result, $pses);
	    }
	    else {
		$self->{'Error'} = "The target for this project has been met, do not pick this plate.";
		return 0;
	    }
	}
	
	$self->{'Error'} = "$pkg: GetAvailPlasmidAgarPlateToPick384() -> Could not find project for barcode = $barcode.";
    }
    else {
	my ($result, $pses) = $self->{'CoreSql'} -> GetAvailBarcodeInInprogress($barcode, $ps_id);
	$self -> {'WGS agar plate'} = 1;
	return ($result, $pses);
    }

    return 0;
} #GetAvailPlasmidAgarPlateToPick384

##########################################
#  main agar plate processing subroutine #
##########################################
sub GetAvailPlasmidAgarPlateOut {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses, $priority) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'out', 'inprogress', 'Plasmid Plating');



    return ($result, $pses, $priority);

} #GetAvailAgarPlateOut

##########################################
#  main agar plate processing subroutine #
##########################################
sub GetAvailPlasmidAgarPlateInOut {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses, $priority) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'in', 'inprogress', 'Plasmid Plating');
    
    if(!$result) {
	($result, $pses, $priority) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'out', 'inprogress', 'Plasmid Plating');

    }
	
    return ($result, $pses, $priority);


} #GetAvailAgarPlateOut

##########################################
#  main agar plate processing subroutine #
##########################################
sub GetAvailPlasmidAgarPlateAP {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'out', 'inprogress', 'Automated Production');
    
    return ($result, $pses);

} #GetAvailAgarPlate

##########################################
#  main agar plate processing subroutine #
##########################################
sub GetAvailM13AgarPlate {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'out', 'inprogress', 'm13 Production');
    
    return ($result, $pses);

} #GetAvailAgarPlate

##########################################
#  main agar plate processing subroutine #
##########################################
sub GetAvailM13AgarPlateToPick {

    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'in', 'inprogress', 'm13 Picking');

    return ($result, $pses);

} #GetAvailAgarPlate





#############################################
#  get available plates for colony counting #
#############################################
sub GetAvailCountColonyAgarPlate {

    my ($self, $barcode, $ps_id) = @_;
    
    my $dbh = $self ->{'dbh'};
    my $schema = $self->{'Schema'};
    
    if(defined $self->{'AgarPlateScanned'}) {
	$self->{'Error'} = "Only one agar plate can be scanned at a time.";
	return 0;
    }
    
    $self->{'AgarPlateScanned'} = 1;
    
    my $purpose = $self->{'CheckClonePurpose'} -> xSql($barcode);
    $purpose = 'genome' unless($purpose);

    if($purpose ne 'genome') {

	my $project_info = $self->{'GetProjectTargetFromAgarPlate'} -> xSql($barcode);
	my $project_id = $project_info->[0][0];
	my $target = $project_info->[0][1];
	
        my $proj = GSC::Project->get(project_id => $project_id);
        unless($proj) {
            $self->{'Error'} = "$pkg: Could not find a project associated with this agar plate.";
            return 0;
        }

	if($proj->project_status !~ /finish/ && $proj->project_status !~ /submit/) {
            my $update = $proj->set_project_status('shotgun_start');
            unless($update) {
                 $self->{'Error'} = "$pkg: Failed to update the project status.";
                 return 0;
            }
        }

	if(defined $project_id) {
	    
	    my $count = $self->{'CheckIfProjectOpen'} -> xSql($project_id, $ps_id);
	    
	    if($count == 0) {
		
		# First check if the ligation needs a qc picked
		my $lig_id = $self->{'GetLigIdFromBarcode'} -> xSql($barcode);
		my $qc_info = $self->{'CheckQcStatusForLigation'} -> xSql($lig_id);
		my $pick_desc96;
		my $pick_desc384;
		my $pick_desc;
		if($qc_info->[0][0] eq 'yes') {
		    my $picked96 = $self->{'GetNumbersPickedForLigation'} -> xSql($lig_id, 'Plasmid Picking', '96 archive plate');
		    if($picked96 == 0) {
			$pick_desc96 = 'pick 1, 96 well plate';
		    }		
		}
		
		# Calculate the number of plates to pick for the project 
		my $picked_archives = $self->{'GetNumbersPickedForProject'} -> xSql($project_id);		    
		$picked_archives = $#{$picked_archives}+1;
		my $arcs2pick = ($target - $picked_archives);


		if($arcs2pick > 0) {
		    my $plates2pick = int($arcs2pick/4);
		    my $remainder = ($arcs2pick % 4);
			
		    # There never should be a remainder but incase there is round up
		    #if((($remainder > 0) && ($qc_info->[0][0] eq 'no')) || (($remainder > 1) && ($qc_info->[0][0] eq 'yes'))) {
		    if($remainder > 0) {
			$plates2pick++;
		    }
		    
		    if($plates2pick > 0) {
			$pick_desc384 = "need $plates2pick, 384 well plate(s)";
		    }

		    if((defined $pick_desc96)&&(defined $pick_desc384)) {
			$pick_desc = $pick_desc96.' or '.$pick_desc384;
		    }
		    elsif(defined $pick_desc384) {
			$pick_desc = $pick_desc384;
		    }
		    elsif(defined $pick_desc96) {
			$pick_desc = $pick_desc96;
		    }
		    else {
			$self->{'Error'} = "Target met for project.  Do not pick this agar plate.";
			return 0;
		    }
		}
		elsif(defined $pick_desc96) {
		    $pick_desc = $pick_desc96;
		}
		else {
		    $self->{'Error'} = "Target met for project.  Do not pick this agar plate.";
		    return 0;
		}
		
		my ($result, $pses, $priority) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'in', 'inprogress', 'Plasmid Picking');
		
		if($result) {
		    return ($pick_desc, $pses, $priority);
		}
		else {
		    $self->{'CheckIfAgarUsedInPick96'} = LoadSql($dbh, "select distinct output_device from process_steps, process_step_executions, 
                                                     pse_barcodes where pse_id = pse_pse_id and ps_id = ps_ps_id and pro_process_to = 'pick' and bs_barcode = ?
                                                     and direction = 'in' and purpose = 'Plasmid Picking'", 'Single');
		    
		    my $output_device = $self->{'CheckIfAgarUsedInPick96'} -> xSql($barcode);
		    
		    if($output_device eq '96 archive plate') {
			my ($result, $pses) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'in', 'completed', 'Plasmid Picking');
			
			if($result) {
			    return ($pick_desc, $pses);
			}
			else {  
			    $self->{'Error'} = "Could not find agar plate description.";
			}
		    }
		    else {
			$self->{'Error'} = "Agar plate not in the correct state, may have been used.";
		    }
		}
	    }
	    else {
		$self->{'Error'} = "Agar plate not available for counting colonies at this time, please check again in a little bit.";
	    }
	}
	else {
	    $self->{'Error'} = "Could not find the project for the agar barcode = $barcode.";
	}
    }
    else {

#	my ($result, $pses) = $self -> GetAvailAgarPlate($barcode, $ps_id, 'in', 'inprogress', 'Plasmid Picking');
        my ($result, $pses) = $self->{'CoreSql'} -> GetAvailBarcodeInInprogress($barcode, $ps_id);
	return ($result, $pses); 
    }
	
    
    return 0;

} #GetAvailCountColonyAgarPlate

#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailPlasmidToClaimAP {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'out', 'Automated Production');
 
    return ($result, $pses);

} #GetAvailPlasmidToClaimAP

#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailM13ToClaim {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'out', 'm13 Production');
 
    return ($result, $pses);

} #GetAvailPlasmidToClaimAP

#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailPlasmidToClaim96 {
    
    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'in', 'Plasmid Picking');
    
    if(!$result) {
	($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'in', 'Automated Production');
	if(!$result) {
	    ($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'out', 'Automated Production');
	}
    }
    return ($result, $pses);

} #GetAvailPlasmidToClaim


#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailPlasmidToClaim {
    
    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'in', 'Plasmid Picking');
    if(!$result) {
	($result, $pses) = $self -> GetAvailSubclone($barcode, '1269', 'inprogress', 'out', 'Automated Production');
    }
    
     return ($result, $pses);

} #GetAvailPlasmidToClaim
#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailFosmidToClaim {
    
    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'in', 'Fosmid Production');
    
    return ($result, $pses);

} #GetAvailPlasmidToClaim

#######################################################
# Get avail plasmid plates to be prep                 #
#######################################################
sub GetAvailPlasmidInInprogress {
    
    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailArchive($barcode, $ps_id, 'inprogress', 'in', 'Archive Prep');
    
    return ($result, $pses);

} #GetAvailPlasmidInInprogress

#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailClaimInoculated {
    
    my ($self, $barcode, $ps_id) = @_;

    my	($result, $pses) = $self->{CoreSql}->GetAvailBarcodeOutInprogress($barcode, $ps_id);
    
=cut
    my	($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'out', 'Plasmid Production');
    

    if(!$result) {
	($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'out', 'Automated Production');
    }
=cut
    return ($result, $pses);

} #GetAvailSubclonesOutInprogress

#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailSubclonesOutInprogress {
    
    my ($self, $barcode, $ps_id) = @_;

    return ($barcode) if($barcode =~ /^empty/);

    my ($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'out', 'Automated Production');

    return ($result, $pses);

} #GetAvailSubclonesOutInprogress

#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailFosmidSubclonesOutInprogress {
    
    my ($self, $barcode, $ps_id) = @_;

    return ($barcode) if($barcode =~ /^empty/);

    my ($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'out', 'Fosmid Production');

    return ($result, $pses);

} #GetAvailSubclonesOutInprogress
#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailFosmidSubclonesInInprogress {
    
    my ($self, $barcode, $ps_id) = @_;

    return ($barcode) if($barcode =~ /^empty/);

    my ($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'in', 'Fosmid Production');

    return ($result, $pses);

} #GetAvailSubclonesOutInprogress

#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailSubclonesOutInprogressMiniPrep {
    
    my ($self, $barcode, $ps_id) = @_;

    return ($barcode) if($barcode =~ /^empty/);

    my ($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'out', 'Mini Prep');

    return ($result, $pses);

} #GetAvailSubclonesOutInprogress


sub GetAvailSubclonesOutInprogressM13 {
    
    my ($self, $barcode, $ps_id) = @_;

    return ($barcode) if($barcode =~ /^empty/);

    my ($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'out', 'm13 Production');

    return ($result, $pses);

} #GetAvailSubclonesOutInprogress

#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailSubclonesInInprogress {
    
    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailSubclone($barcode, $ps_id, 'inprogress', 'in', 'Automated Production');

    return ($result, $pses);

} #GetAvailSubclonesInInprogress


#################################
# get archive in subclones pses #
#################################
sub GetAvailSubclone {

    my ($self, $barcode, $ps_id, $status, $direction, $purpose) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
						
    my $lol = $self -> {'GetAvailSubclone'} ->xSql($status, $barcode, $direction, $ps_id, $purpose);
    
    if(defined $lol->[0][0]) {
	my @arcs;
	my $pses = [];
	for my $i (0 .. $#{$lol}) {
	    push(@arcs, $lol->[$i][2]);
	    push(@{$pses}, $lol->[$i][3]);
	}
	
	my $desc = $lol->[0][0].' '.$lol->[0][1]." @arcs";
	return ($desc, $pses);
    }
	
    $self->{'Error'} = "$pkg: GetAvailSubclone() -> Could not find barcode description information for barcode = $barcode, ps_id = $ps_id, status = $status.";
    
	
    return 0;

} #GetAvailSubclone



#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailArchivesToInoculate384AP {
    
    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailArchive($barcode, $ps_id, 'inprogress', 'in', 'Automated Production');

    return ($result, $pses);

} #GetAvailArchivesToInoculate

######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailArchivesToInoculate96 {
    
    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailArchive($barcode, $ps_id, 'inprogress', 'in', 'Plasmid Production');

    return ($result, $pses);

} #GetAvailArchivesToInoculate

######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailArchivesToInoculate384 {
    
    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailArchive($barcode, $ps_id, 'inprogress', 'in', 'Plasmid Production');

    return ($result, $pses);

} #GetAvailArchivesToInoculate


#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailArchiveInInprogress {
    
    my ($self, $barcode, $ps_id) = @_;

    return ($barcode) if($barcode =~ /^empty/);
    my ($result, $pses) = $self -> GetAvailArchive($barcode, $ps_id, 'inprogress', 'in', 'Automated Production');

    return ($result, $pses);

} #GetAvailArchivesToInoculate

#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailFosmidArchiveInInprogress {
    
    my ($self, $barcode, $ps_id) = @_;

    return ($barcode) if($barcode =~ /^empty/);
    my ($result, $pses) = $self -> GetAvailArchive($barcode, $ps_id, 'inprogress', 'in', 'Fosmid Production');

    return ($result, $pses);

} #GetAvailArchivesToInoculate


#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailArchiveInInprogressM13 {
    
    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailArchive($barcode, $ps_id, 'inprogress', 'in', 'm13 Production');

    return ($result, $pses);

} #GetAvailArchiveInInprogressM13


#######################################################
# Get avail plasmid plates to claim from picking core #
#######################################################
sub GetAvailArchiveInCompletedM13 {
    
    my ($self, $barcode, $ps_id) = @_;

    my ($result, $pses) = $self -> GetAvailArchive($barcode, $ps_id, 'completed', 'in', 'm13 Production');

    return ($result, $pses);

} #GetAvailArchiveInCompletedM13


#################################
# get archive in subclones pses #
#################################
sub GetAvailArchive {

    my ($self, $barcode, $ps_id, $status, $direction, $purpose) = @_;

    my $lol = $self -> {'GetAvailArchive'} ->xSql($status, $barcode, $direction, $ps_id, $purpose);
    
    if(defined $lol->[0][0]) {
	my @arcs;
	my $pses = [];
	for my $i (0 .. $#{$lol}) {
	    push(@arcs, $lol->[$i][2]);
	    push(@{$pses}, $lol->[$i][3]);
	}
	
	my $desc = $lol->[0][0].' '.$lol->[0][1]." @arcs";
	return ($desc, $pses);
    } else {
      my($result, $pses) = $self->{CoreSql}->GetAvailBarcodeInInprogress($barcode, $ps_id);
      if($pses) {
        return ($result, $pses);
      }
    }

    $self->{'Error'} = "$pkg: GetAvailArchive() -> Could not find barcode description information for barcode = $barcode, ps_id = $ps_id, status = $status.";
    
	
    return 0;

} #GetAvailArchive


sub GetAvailSequenceOutInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my $status = 'inprogress';
    my $direction = 'out';
    my ($result, $pses) = $self->GetAvailSeqDna($barcode, $ps_id, $status, $direction, 'Automated Production');

    return ($result, $pses);

} #GetAvailSequenceToRearray

sub GetAvailSequenceOutOrInInprogress {

    my ($self, $barcode, $ps_id) = @_;

    my $status = 'inprogress';
    my $direction = 'out';
    my ($result, $pses) = $self->GetAvailSeqDna($barcode, $ps_id, $status, $direction, 'Automated Production');
   
    if(!$result) {
	my $lol = $self -> {'GetAvailSeqDnaResuspendInput'} ->xSql($status, $barcode, 'in', $ps_id, 'Automated Production' );
    
	if(defined $lol->[0][0]) {
	    my @arcs;
	    my $pses = [];
	    for my $i (0 .. $#{$lol}) {
		push(@arcs, $lol->[$i][2]);
		push(@{$pses}, $lol->[$i][3]);
	    }
	    
	    my $desc = $lol->[0][0].' '.$lol->[0][1]." @arcs";
	    return ($desc, $pses);
	}
    }
    return ($result, $pses);

} #GetAvailSequenceToRearray


sub GetAvailSequenceToRearray {

    my ($self, $barcode, $ps_id) = @_;

    return ($barcode) if($barcode =~ /^empty/);

    my $status = 'inprogress';
    my $direction = 'in';

    my ($result, $pses) = $self->GetAvailSeqDna($barcode, $ps_id, $status, $direction, 'Automated Production');

    return ($result, $pses);

} #GetAvailSequenceToRearray


###############################
# Get available sequenced dna #
###############################
sub GetAvailSeqDna {

    my ($self, $barcode, $ps_id, $status, $direction, $purpose) = @_;

    my $lol = $self -> {'GetAvailSeqDna'} ->xSql($status, $barcode, $direction, $ps_id, $purpose);
    
    if(defined $lol->[0][0]) {
	my @arcs;
	my $pses = [];
	for my $i (0 .. $#{$lol}) {
	    push(@arcs, $lol->[$i][2]);
	    push(@{$pses}, $lol->[$i][3]);
	}
	
	my $desc = $lol->[0][0].' '.$lol->[0][1]." @arcs";
	return ($desc, $pses);
    }
    
    $self->{'Error'} = "$pkg: GetAvailSeqDna() -> Could not find barcode description information for barcode = $barcode, ps_id = $ps_id, status = $status.";
	
    return 0;

} #GetAvailSeqDna
 
sub GetFailBarcodeDesc {

    my ($self, $barcode, $ps_id) = @_;
    
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};

    $self->{'CheckBarcodeDescStatus'} = LoadSql($dbh, "select distinct pse_id from process_step_executions, pse_barcodes where 
               bs_barcode = ? and psesta_pse_status = 'inprogress' and  pse_pse_id = pse_id", 'List');
    my $lov = $self->{'CheckBarcodeDescStatus'} -> xSql($barcode);

    if(defined $lov->[0]) {
	my $desc = $self->{'CoreSql'}->Process('BarcodeDesc', $barcode);
	my $pses = [];
	foreach my $pse (@{$lov}) {
	    push(@{$pses}, $pse);
	}
	
	return ($desc, $pses);
    }

    $self->{'Error'} = "$pkg: GetFailBarcodeDesc() -> Could not find a pse inprogresss for barcode = $barcode and ps_id = $ps_id.";
	
    return 0;

}





sub GetAvailMiniPrepInocInput {
    
    my ($self, $barcode, $ps_id) = @_;

    my $lol = $self -> {'GetAvailMiniPrep'} ->xSql('inprogress', 'miniprep', 'Finisher Request', $barcode, 'out');
    
    if(defined $lol->[0][0]) {
	my @arcs;
	my $pses = [];
	for my $i (0 .. $#{$lol}) {
	    push(@arcs, $lol->[$i][2]);
	    push(@{$pses}, $lol->[$i][3]);
	}
	
	my $desc = $lol->[0][0].' '.$lol->[0][1]." @arcs";
	return ($desc);
    }
    
    $self->{'Error'} = "$pkg: GetAvailMiniPrepInocInput() -> Could not find subclones requested for barcode = $barcode";
    
	
    return 0;

} #GetAvailMiniPrepInocInput


sub GetAvailSubclonePassCheckGel {

    my ($self, $barcode, $ps_id) = @_;
    my $direction = 'out';
    my $status = 'completed';
    my $result = 'successful';


    my $lol = $self->{'GetAvailSubcloneGelCheck'} -> xSql($status, $result, $barcode, $direction, $ps_id, 'Mini Prep');
    
    if(defined $lol->[0][0]) {
	return ($lol->[0][0].' '.$lol->[0][1].' '.$lol->[0][2], [$lol->[0][3]]);
    }

    $self->{'Error'} = "$pkg: GetAvailSubclonePassCheckGel() -> Could not find clone description information for barcode = $barcode, ps_id = $ps_id, status = $status.";

    return 0;

} #GetAvailSubclonePassCheckGel


################################################################################
#                                                                              #
#                              Output verification subroutines                 #
#                                                                              #
################################################################################


sub CheckProjectTarget {

    my ($self, $barcode) = @_;

       
    if(! $self -> {'WGS agar plate'}) {

	if(! $self -> {'TargetMet'}) {
	    if($self->{'PlatesScanned'} < $self->{'MaxPlatesToPick'}) {
		my $result = $self -> CheckIfUsedAsOutput($barcode);
		$self->{'TargetMet'} = 0;
		
		if($result) {
		    
		    $self->{'PlatesScanned'}++;
		    if($self->{'PlatesScanned'} == $self->{'MaxPlatesToPick'}) {
			$self->{'TargetMet'} = 1;
			$self -> {'Error'} = "$pkg: CheckProjectTarget() -> The has been met, do not scan anymore plates.";
		    }
		    return $result;
		}
		return 0;
	    }	
	    
	    $self -> {'Error'} = "$pkg: CheckProjectTarget() -> The target will be met for the number of outputs already scanned.";
	    return 0;
	}
	else {
	    $self -> {'Error'} = "$pkg: CheckProjectTarget() -> The has been met, do not scan anymore plates.";
	    return 0;
	}
    }
    else {

	my $result = $self -> CheckIfUsedAsOutput($barcode);
	return $result;
	
    }

    return 0;

} #CheckProjectTarget

##########################################
#     Output verification Subroutines    #
##########################################
sub CheckIfUsedAsOutput {

    my ($self, $barcode) = @_;

    return ($barcode) if($barcode =~ /^empty/);

    my $desc = $self->{'CoreSql'} -> CheckIfUsed($barcode, 'out');
    return ($self->GetCoreError) if(!$desc);
    return $desc;

} #CheckIfUsedAsOutput

############################################################
# Get the Available quadrants for a 384 plate to inoculate #
############################################################
sub GetAvailableQuads {

    my ($self, $barcode) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
    my $lol = $self->GetAvailableQuadsPses($barcode);
   
    if(defined $lol && defined $lol->[0] && defined $lol->[0][0]) {
	my $quads = [];
	foreach my $quad (@{$lol}) {
	    push(@{$quads}, $quad->[0]);
	}
	
	return $quads;
    }

    $self -> {'Error'} = "$pkg: GetAvailableQuads() -> Could not find available quadrants:\n ".App::DB->error_message;
    return 0;

} #GetAvailableQuads
############################################################
# Get the Available quadrants for a 384 plate to inoculate #
############################################################
sub GetAvailableQuadsPses {

    my ($self, $barcode) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
    my $lol = $self->{'GetAvailableQuadsPses'} -> xSql($barcode);
    
    #Hard code for spec step to always have four pses match for quadrants, changed when the fosmids had 
    #the same arc_id in every quadrant
    
# my $lol = $self->{'GetAvailableQuadsArcPses'} -> xSql($barcode);
 
    if(defined $lol->[0][0]) {

	if($#{$lol} == 3) { 
	    
	    my $i = 0;
	    foreach my $quad qw(A1 A2 B1 B2) {
		$lol->[$i][0] = $quad;
		$i++;
	    }
	    
	    

	    return $lol;
	}
	else {
	    $self -> {'Error'} = "$pkg: GetAvailableQuadsPses() -> The number of pses does not match the set number of quadrants";
	    return 0;
	}
    }

    $self -> {'Error'} = "$pkg: GetAvailableQuadsPses() -> Could not find available quadrants.";
    return 0;

} #GetAvailableQuadsPses

sub GetMiniPrepPlateLocations{

    my ($self, $barcode) = @_;

    my $lol = $self -> {'GetSubcloneLocations'} ->xSql('inprogress', 'miniprep', 'Finisher Request', $barcode, 'out');
   
    if(defined $lol->[0][0]) {
	my $wells = [];
	foreach my $well (@{$lol}) {
	    push(@{$wells}, $well->[0]);
	}
	
	return $wells;
    }
    
    $self -> {'Error'} = "$pkg: GetMiniPrepPlateLocations() -> Could not find plate locations.";
    return 0;

} #GetMiniPrepPlateLocations



sub GetArchivePurpose {

    my ($self, $ps_id, $desc, $barcode) = @_;

    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});

    my ($pso_id, $data, $lov) = $TouchSql -> GetPsoInfo($ps_id, $desc);
    
    $TouchSql -> destroy;

    my $purpose = $self -> {'GetArchivePurposeFromBarcode'} -> xSql($barcode->[0]);
    
    if((defined $purpose) && ($purpose ne 'unknown')) {
	
	return ($pso_id, $purpose, $lov);
	
    }
    
    return ($pso_id, $data, $lov);

} #GetProjectTarget

sub GetClonePrefix {

    my ($self, $ps_id, $desc, $barcode) = @_;

    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});

    my ($pso_id, $data, $lov) = $TouchSql -> GetPsoInfo($ps_id, $desc);
    
    $TouchSql -> destroy;

    my $dv = 'PPAD';    
	
    my @list = map {$_->clone_prefix} GSC::Clone->get(clone_type => 'fosmid library');
    @list = sort @list;
    return ($pso_id, $dv, \@list);
	
    
    return ($pso_id, $data, $lov);

} #GetProjectTarget

############################################################################################
#                                                                                          #
#                         Confirm Subrotine Processes                                      #
#                                                                                          #
############################################################################################

sub CountColonies {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $data_options = $options->{'Data'};
    if(defined $data_options) {
	
	foreach my $pso_id (keys %{$data_options}) {
	    my $info = $data_options -> {$pso_id};
            unless($info) {
                $self->{'Error'} = "Failed to to total colonies or total pickables.";
                return 0;
            }
            
            if($$info eq '') {
                $self->{'Error'} = "Failed to to total colonies or total pickables.";
                return 0;
            }
	}
    }
    else {
        $self->{'Error'} = "Failed to to total colonies or total pickables.";
        return 0;
    }
    
    my $pse_ids = $self->{'CoreSql'}->ProcessDNA($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids);


    foreach my $pse_id (@$pse_ids) {
        my $dp = GSC::DNAPSE->get(pse_id => $pse_id);
        return unless($dp);
        
        my $dna = GSC::DNA->get($dp->dna_id);
        return unless($dna);
        
        if($dna->dna_name =~ /^U_AR/) {
            my $pse=GSC::PSE->get(pse_id => $pse_id);
            return unless($pse);
            $pse->pse_status('completed');
            $pse->pse_result('successful');
        }
                                  
    }

    return $pse_ids;
} #CountColonies


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
    
#    my $result = $self -> InsertLigationsPses($lig_id, $new_pse_id,'');
#    return 0 if($result == 0);
    my $dl_id = Query($self->{'dbh'}, qq/select dl_id from dna_location where location_type = 'tube' and location_name = '1'/);
    my $result = $self->{'CoreSql'} -> InsertDNAPSE($lig_id, $new_pse_id, $dl_id);
    return 0 if($result == 0);

    push(@{$pse_ids}, $new_pse_id);
    return $pse_ids;
} #ProcessLigation


#############################################
# Process a 96 pick archive barcode request #
#############################################
sub Pick96PlasmidArchive {
    
    my ($self, $ps_id, $bar_in, $bar_outs, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = $self -> PickArchive($ps_id, $bar_in, $bar_outs, $emp_id, $options, $pre_pse_ids, '96', 'qc');
    
    return $pse_ids;
} #Pick96PlasmidArchive


#############################################
# Process a 96 pick archive barcode request #
#############################################
sub Pick96PlasmidArchiveAP {
    
    my ($self, $ps_id, $bar_in, $bar_outs, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = $self -> PickArchive($ps_id, $bar_in, $bar_outs, $emp_id, $options, $pre_pse_ids, '96', 'production');
    
    return $pse_ids;
} #Pick96PlasmidArchive


#############################################
# Process a 96 pick archive barcode request #
#############################################
sub Pick96ProductionArchive {

    my ($self, $ps_id, $bar_in, $bar_outs, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = $self -> PickArchive($ps_id, $bar_in, $bar_outs, $emp_id, $options, $pre_pse_ids, '96', 'production');

    return $pse_ids;
} #Pick96ProductionArchive

##############################################
# Process a 384 pick archive barcode request #
##############################################
sub Pick384ProductionArchive {

    my ($self, $ps_id, $bar_in, $bar_outs, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = $self -> PickArchive($ps_id, $bar_in, $bar_outs, $emp_id, $options, $pre_pse_ids, '384', 'production');

    return $pse_ids;
} #Pick384ProductionArchive



###############################################
# Process a 96 pick archive barcode request #
#############################################
sub PickArchive {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, $plate_type, $purpose) = @_;

    my $pse_id=[];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $pre_pse_id = $pre_pse_ids->[0];
    my @sectors;
    
    
    my $data_options = $options->{'Data'};
    if(defined $data_options) {
	
	foreach my $pso_id (keys %{$data_options}) {
	    my $info = $data_options -> {$pso_id};
	    if(defined $info) {
		my $sql = "select OUTPUT_DESCRIPTION from process_step_outputs where pso_id = '$pso_id'";
		my $desc = Query($self->{'dbh'}, $sql);
		if($desc eq 'archive purpose') {
		    $purpose = $$info;
		}
		if($desc eq 'status') {
		    if($$info eq 'inprogress') {
			$update_status = $$info;
			$update_result = '';
		    }
		}
	    }
	}
    }

    if($plate_type eq '96') {
	push(@sectors, 'a1');
    }
    elsif($plate_type eq '384') {
	push(@sectors, qw(a1 a2 b1 b2));
    }
    else {
	$self->{'Error'} = "$pkg: PickArchive() -> Not a valid plate type, use 384 or 96.";
    }

    my $lig_id = $self->{'GetLigIdFromPse'} -> xSql($pre_pse_id);
    return 0 if($lig_id == 0);

    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', $plate_type);
    return 0 if($pt_id == 0);
        
    foreach my $bar_out (@{$bars_out}) {

	foreach my $sector (@sectors) {

	    my $sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', $sector);
	    return ($self->GetCoreError) if(!$sec_id);

	    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out], $emp_id);
	    return ($self->GetCoreError) if(!$new_pse_id);

            my $lig = GSC::DNA->get(dna_id => $lig_id);

            my $dna_resource = $lig -> get_dna_resource;
            my $new_archive = $dna_resource->next_archive;
            my $arc_obj =  GSC::Archive->create(archive_number => $new_archive,
                                                available => 'NO', 
                                                group_name => 'unknown', 
                                                purpose => $purpose,
                                                );
            my $arc_id = $arc_obj->arc_id;

	    # Generate Subclones
	    my $result = $self -> GenerateSubclonesAndLocations($new_pse_id, $lig_id, $arc_id, $pt_id, $sec_id);
	    return 0 if (!$result);

	    push(@{$pse_id}, $new_pse_id);
	}
    }

    return $pse_id;
} #PickArchive

sub CreateOutOfHouseFosmids384 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = $self -> CreateOutOfHouseFosmids($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, '384');
    
    return $pse_ids;
} #Pick384ProductionArchive
sub CreateOutOfHouseFosmids96 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $pse_ids = $self -> CreateOutOfHouseFosmids($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, '96');
    
    return $pse_ids;
} #Pick384ProductionArchive


sub CreateOutOfHouseFosmids {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids, $plate_type) = @_;

    my $pse_id=[];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $pre_pse_id = 1;
    my @sectors;
    
    my $plate_name;
    my $prefix_name;
    
    my $data_options = $options->{'Data'};
    foreach my $pso (keys %{$data_options}) {
	my $desc = $self->{'GetPsoDescription'} -> xSql($pso);
	my $data = $data_options->{$pso};
	if(defined $$data) {
	    if($desc eq 'plate name') {
		if($$data !~  /^(\d\d\d)|(\d\d\d\d)$/) {
		    $self->{'Error'} = "$pkg: CreateOutOfHouseFosmids -> Incorrect plate name format, must be 4 digits.";
		    return 0;
		}
                $plate_name = $$data;
	    }
            elsif ($desc eq 'Clone Prefix')
            {
                $prefix_name = $$data;
            }
	}
    }

    # Get the clone prefix and default fake ligation for this species
    my $data = $self -> {'GetFosmidLigCloPrefix'} -> xSql($prefix_name);

    if (@$data == 0)
    {
        $self->{'Error'} = "$pkg: CreateOutOfHouseFosmids -> No prefix/fake-ligation pair found for $prefix_name fosmids.  Contact Informatics.";
        return 0;    
    }
    
    if (@$data > 1)
    {
        $self->{'Error'} = "$pkg: CreateOutOfHouseFosmids -> Multiple prefix/fake-ligation pair found for $prefix_name fosmids???  Contact Informatics.";
        return 0;        
    }
    
    my ($lig_id,$clone_prefix) =  @{ $data->[0] };
    
    return 0 if($lig_id == 0);

    my $purpose= 'production';
    if($plate_type eq '96') {
	push(@sectors, 'a1');
    }
    elsif($plate_type eq '384') {
	push(@sectors, qw(a1 a2 b1 b2));
    }
    else {
	$self->{'Error'} = "$pkg: PickArchive() -> Not a valid plate type, use 384 or 96.";
    }
    

    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', $plate_type);
    return 0 if($pt_id == 0);
        
    foreach my $bar_out (@{$bars_in}) {

	foreach my $sector (@sectors) {

	    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, undef, [$bar_out], $emp_id);
	    return ($self->GetCoreError) if(!$new_pse_id);

	    my $ArchiveNumber =$clone_prefix . "-". $plate_name;
#	    my $ArchiveNumber =$clone_prefix . $plate_name;
            my $arc = GSC::Archive->get
            (                
                archive_number => $ArchiveNumber,
            );
	    

	    if(! defined $arc) {
		$arc = GSC::Archive->create
		    (                
				     archive_number => $ArchiveNumber,
				     available => 'NO',
				     group_name => 'unknown',
				     purpose => $purpose
				     );
	    }
	    else {
		$self->{'Error'} = "$pkg: CreateOutOfHouseFosmids -> Archive number:  ".$clone_prefix.$plate_name." already exists."
	    }
            
            unless ($arc)
            {
                $self->{'Error'} = "$pkg: CreateOutOfHouseFosmids -> Failed to create an archive entry for ${clone_prefix}${plate_name}: " . GSC::Archive->error;
                return 0;
            }
            

	    my $sector_obj = GSC::Sector->get(sector_name => $sector);
	    my @dna_locs = GSC::DNALocation->get(location_type => $plate_type.' well plate',
						 sec_id => $sector_obj->sec_id);
	    
	    foreach my $dna_loc (@dna_locs) {
	    
		# Build subclone name
		my $subclone = $ArchiveNumber.uc($dna_loc->location_name);
		
		my $result = GSC::Subclone->create(subclone_name => $subclone, 
						   arc_id => $arc->arc_id,
						   parent_dna_id => $lig_id,
						   pse_id => $new_pse_id,
						   dl_id => $dna_loc->dl_id);
		return 0 if(!$result);
	    }
	
	    push(@{$pse_id}, $new_pse_id);
	}
    }

    return $pse_id;

}#CreateOutOfHouseFosmids


sub ReplicateFosmidPlates {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i=0;    
    
    #---- because of newfanlged spec steps, the prior pse and the dna source pse may be different.... so we do this
    my @dna_source_pses;
    my @prior_pses;
    #===================== this all should be cut out
    if(@$pre_pse_ids > 1){
	#-- please note: this is for old steps.  Once every spec machine is running on optimus prime or higher, this entire
	#   block can be taken out!
	my $priors =  $self->GetAvailFosmidSubclonesInInprogress($bars_in->[0], $ps_id);
	if($priors){
	    @dna_source_pses = @prior_pses = sort {$b <=> $a} @$priors;
	}
	else{
	    #--- one more try for special cases.  REALLY HACKY
	    my $bc = GSC::Barcode->get($bars_in->[0]);
	    unless($bc){
		$self->{Error} = 'no barcode found';
		return;
	    }
	    my %dp = map {$_->pse_id => $_} $bc->get_dna_pse;
	    unless(%dp){
		$self->{Error} = 'failed to find dna pses for '.$bc->barcode;
		return;
	    }
	    @dna_source_pses = sort keys %dp;
	    foreach my $dsp(@dna_source_pses){
		my @tpp = GSC::TppPSE->get(prior_pse_id => $dsp, pse_id => $pre_pse_ids);
		if(@tpp == 1){
		    push @prior_pses, $tpp[0]->pse_id;
		}
		elsif(@tpp > 1){
		    $self->{Error} = "No old style replication priors found, and too many out of house priors found!";
		    return;
		}
		else{
		    $self->{Error} = 'No priors found for old style replication';
		    return;
		}
	    }
	}

    }
    #------------------ resume real processing
    else{
	#-- this appropriately handles the new fashion.  Hopefully we will upgrade to transfer patterns soon, no ?
	my $bc = GSC::Barcode->get($bars_in->[0]);
	unless($bc){
	    $self->{Error} = 'no barcode found';
	    return;
	}
	my %dp = map {$_->pse_id => $_} $bc->get_dna_pse;
	unless(%dp){
	    $self->{Error} = 'failed to find dna pses for '.$bc->barcode;
	    return;
	}
	@dna_source_pses = sort keys %dp;
	@prior_pses = map {$pre_pse_ids->[0]} (0..$#dna_source_pses);
    }
    
    
    foreach my $bar_out (@$bars_out) {
	next if($bar_out =~ /^empty/);
	foreach my $dna_source_pse (@dna_source_pses) {
	    my $pre_pse_id = shift @prior_pses;
	    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out], $emp_id);
	    
	    my $result = $self -> Trans96To96($bars_in->[0], $dna_source_pse, $new_pse_id, 'subclone');
	    return 0 if($result == 0);
	    
	    push(@{$pse_ids}, $new_pse_id);
	    
	    $i++;
	}
    }
	
    return $pse_ids;
    
}#ReplicateFosmidPlates

#######################################
# Process Claim Archive Barcode Request #
#########################################
sub ClaimArchivePlate {

    my ($self, $ps_id, $bars_in, $bar_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $purpose;
    
    my $data = $options->{'Data'};
    if(defined $data) {
	my @key = keys %{$data};
	$purpose = ${$data -> {$key[0]}};
    }
    

    my $group = $self->{'CoreSql'} -> Process('GetGroupForPsId', $ps_id);
    return ($self->GetCoreError) if($group eq '0');

    foreach my $pre_pse_id (@{$pre_pse_ids}) {

	my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bar_out, $emp_id);
	return ($self->GetCoreError) if(!$new_pse_id);

	my $arc_id = $self -> GetArcIdFromPseInSubPses($pre_pse_id);
	return 0 if($arc_id==0);

	my $result = $self -> InsertArchivesPses($new_pse_id, $arc_id);
	return 0 if($result == 0);

	$result = $self -> UpdateArchiveGroup($group, $arc_id);
	return 0 if(!$result);

	if(defined $purpose) {

	    $result = $self -> UpdateArchivePurpose($arc_id, $purpose);
	}

	push(@{$pse_ids}, $new_pse_id);
    }

    return $pse_ids;
} #ClaimArchive


#######################################
# Process Prep Archive                #
#######################################
sub PrepArchive {

    my ($self, $ps_id, $bars_in, $bar_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $group = $self->{'CoreSql'} -> Process('GetGroupForPsId', $ps_id);
    return ($self->GetCoreError) if($group eq '0');

    foreach my $pre_pse_id (@{$pre_pse_ids}) {

 	my ($fnew_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out->[0]], $emp_id);
	return ($self->GetCoreError) if(!$fnew_pse_id);
	my ($rnew_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out->[1]], $emp_id);
	return ($self->GetCoreError) if(!$rnew_pse_id);

        #LSF: Do the forward and reverse.
	my $archive = GSC::ArchivePSE->get(pse_id => $pre_pse_id);
	unless($archive) {
	  $self->{'Error'} = "Could not find the archive with prior pse_id = $pre_pse_id.";
	  return 0;
	}
	my @ss      = GSC::Subclone->get(arc_id => $archive->arc_id);
	unless(@ss) {
	  $self->{'Error'} = "Could not find the subclone with archive id = " . $archive->arc_id . "!\n";
	  return 0;
	}
	#my @dps = GSC::DNAPSE->get(pse_id => $pre_pse_id);
	my @dps = GSC::DNAPSE->get(dna_id => \@ss);
	unless(@dps) {	
	  $self->{'Error'} = "Could not find the dna_pse for the archive id " . $archive->arc_id . "!\n";
	  return 0;
	}
	my $pse = GSC::PSEBarcode->get(pse_id => \@dps, direction => 'out', barcode => $bars_in);
	unless($pse) {
	  $self->{'Error'} = "Could not find the out barcode for the archive id " . $archive->arc_id . "!\n";
	  return 0;	
	}
	foreach my $dp (@dps) {
	  if($pse->pse_id != $dp->pse_id) {
	    next;
	  }
	  unless(GSC::DNAPSE->create(dl_id => $dp->dl_id, 
	                             pse_id => $fnew_pse_id,
				     dna_id => $dp->dna_id)) {
	    $self->{'Error'} = "Could not create the dna_pse for dl_id [" . $dp->dl_id . "] pse_id [" . $fnew_pse_id . "] dna_id [" . $dp->dna_id . "].";
	    return 0;
	  }
	  unless(GSC::DNAPSE->create(dl_id => $dp->dl_id, 
	                             pse_id => $rnew_pse_id,
				     dna_id => $dp->dna_id)) {
	    $self->{'Error'} = "Could not create the dna_pse for dl_id [" . $dp->dl_id . "] pse_id [" . $rnew_pse_id . "] dna_id [" . $dp->dna_id . "].";
	    return 0;
	  }
	}
	
	push(@{$pse_ids}, $fnew_pse_id);
	push(@{$pse_ids}, $rnew_pse_id);
    }

    return $pse_ids;
} #ClaimArchive

##########################################
# Inoculate from a 384 plate to 96 plate #
##########################################
sub InoculateMiniPrep {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i=0;

    my $wells= $self -> {'GetSubcloneLocations'} ->xSql('inprogress', 'miniprep', 'Finisher Request', $bars_in->[0], 'out');
    
    foreach my $row (@{$wells}) {
	
	my $well = $row->[0];
	if(! defined $well) {
	    $self->{'Error'} = "Could not find a valid well.";
	    return 0;
	}

	my $pre_pse_id = $row->[1];
	if(! defined $pre_pse_id) {
	    $self -> {'Error'} = "Could not find a valid pre_pse_id.";
	}
	    
	my $bar_out = $bars_out->[$i];
	if(! defined $bar_out) {
	    $self -> {'Error'} = "Could not find a output barcode.";
	}
	
	my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out], $emp_id);
   

 	my $result = $self -> Trans96To96($bars_in->[0], $pre_pse_id, $new_pse_id, 'subclone');
	return 0 if($result == 0);

	push(@{$pse_ids}, $new_pse_id);

        $i++;
     }
    
    return $pse_ids;

} #InoculateMiniPrep





sub InoculateMiniPrepCreateSubclones {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $pses=[];
    my $plate_type = '96';
    my $purpose = 'finishing';
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $pre_pse_id = $pre_pse_ids->[0];
    my $sectors;
    
    my $lig_id = $self->{'GetLigIdFromPse'} -> xSql($pre_pse_id);
    return 0 if($lig_id == 0);

    my $pl_id = 0;

    my $result = $self ->{'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
    return ($self->GetCoreError) if(!$result);
    
    my $group = $self->{'CoreSql'} -> Process('GetGroupForPsId', $ps_id);
    return ($self->GetCoreError) if($group eq '0');

    my $arc_id = $self -> GetNextArcId;
    return 0 if(!$arc_id);
    
    my $result1 = 0;
    my $ArchiveNumber;
    while($result1==0) {
	# Get next Archive
	$ArchiveNumber = $self -> GetNextArchiveNumber('gsc');
	return 0 if (!$ArchiveNumber);
	
	# Insert New Archive number
	$result1 = $self -> InsertArchiveNumber($arc_id, $ArchiveNumber, 'NO', $group, $purpose);
	#return 0 if (!$result);
    }
    
    my @rows  = qw(a b c d e f g h);
    my ($i, $j);
    my $count = 0;

    for ($j=0;$j<=$#rows;$j++) {
	for($i=1;$i<=12;$i++) {
    
	    if($count <= $#{$bars_out}) {
		my $bar_out = $bars_out->[$count];
		my $new_pse_id = $self -> {'CoreSql'} -> BarcodeProcessEvent($ps_id, $bars_in->[0], [$bar_out], 'inprogress', '', $emp_id, undef, $pre_pse_ids->[0]);
		return ($self->GetCoreError) if(!$new_pse_id);
		
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
		
		# insert subclone
		my $result = $self -> InsertSubclones($subclone, $lig_id, $sub_id, $arc_id, $new_pse_id);
		return 0 if(!$result);
		
		
		# insert subclones_pses
		#$result = $self -> InsertSubclonesPses($new_pse_id, $sub_id, $pl_id);
		#return 0 if(!$result);
		
		$count++;
		push(@{$pses}, $new_pse_id);
	    }
	    else {
		last;
	    }
	}
    }
    

    return $pses;
} #InoculateMiniPrepCreateSubclones

#######################################
# Process Claim Archive Barcode Request #
#########################################

sub ClaimArchivePlateInoc {
    
    my ($self, $ps_id, $bars_in, $bar_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $dbh = $self->{'dbh'};
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $type = 0;
    my %quadrant;

    my $data_options = $options->{'Data'};
    if(defined $data_options) {
	
	foreach my $pso_id (keys %{$data_options}) {
	    my $info = $data_options -> {$pso_id};
	    if(defined $info) {
		my $sql = "select OUTPUT_DESCRIPTION from process_step_outputs where pso_id = '$pso_id'";
		my $desc = Query($dbh, $sql);
		$quadrant{$desc} = $$info;
		$type = 384;
	    }
	}
    }
    
    my $group = $self->{'CoreSql'} -> Process('GetGroupForPsId', $ps_id);
    return ($self->GetCoreError) if($group eq '0');

    foreach my $pre_pse_id (@$pre_pse_ids){

	my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bar_out, $emp_id);
	return ($self->GetCoreError) if(!$new_pse_id);
	
	my $arc_id = $self -> GetArcIdFromPseInSubPses($pre_pse_id);
	if($arc_id==0){
	    if(@$pre_pse_ids == 1){
		#--get all the archives for the dna
		my @source_dna_pse = $self->dna_source_pses($bars_in->[0]);
		my %archives;
		foreach my $source_pse_id(@source_dna_pse){
		    my $arc_id = $self -> GetArcIdFromPseInSubPses($source_pse_id);
		    return 0 unless $arc_id;
		    unless($archives{$arc_id}){
			$archives{$arc_id} = 1;
			my $result = $self -> InsertArchivesPses($new_pse_id, $arc_id);
			return 0 if($result == 0);
			$result = $self -> UpdateArchiveGroup($group, $arc_id);
			return 0 if(!$result);
		    }
		    my $sql = "select distinct UPPER(sector_name) from sectors, 
                    plate_locations, subclones_pses scx, subclones sc, plate_types
                    where scx.pse_pse_id = '$source_pse_id' and 
                    sub_sub_id = sub_id and pl_pl_id = pl_id and sec_sec_id = sec_id and pt_pt_id = pt_id and well_count = '384'";
		    
		    my $sector = Query($dbh, $sql);
		    my $purpose = $quadrant{$sector};
                    if(defined $purpose) {
			my $result = $self -> UpdateArchivePurpose($arc_id, $purpose);
		    }

                }
            }
            else{
		return 0 ;
	    }
        }
	else{
	    my $result = $self -> InsertArchivesPses($new_pse_id, $arc_id);
	    return 0 if($result == 0);
	    $result = $self -> UpdateArchiveGroup($group, $arc_id);
	    return 0 if(!$result);

	    my $sql = "select distinct UPPER(sector_name) from sectors, 
                    plate_locations, subclones_pses scx, subclones sc, plate_types
                    where scx.pse_pse_id = '$pre_pse_id' and 
                    sub_sub_id = sub_id and pl_pl_id = pl_id and sec_sec_id = sec_id and pt_pt_id = pt_id and well_count = '384'";
	    
	    my $sector = Query($dbh, $sql);
	    my $purpose = $quadrant{$sector};
            if(defined $purpose) {
		$result = $self -> UpdateArchivePurpose($arc_id, $purpose);
	    }
        }
    push(@{$pse_ids}, $new_pse_id);
    }

    return $pse_ids;
} #ClaimArchive





##########################################
# Inoculate from a 384 plate to 96 plate #
##########################################
sub Inoculate384to96 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i=0;
    my %dd; #-- this is a hash of sector name to [ prior pse, dna_source_pse 

    #------------------------ we need to get the dna and the dan source pse and organize them for the prior pses
    if(@$pre_pse_ids == 1){  
	my %sec_pse;
	my $bc =  GSC::Barcode->get($bars_in->[0]);
	my @dp = $bc->get_dna_pse;
	my %dl = map {$_->dl_id => $_} GSC::DNALocation->get(dl_id => \@dp);
	foreach (@dp){
	    if(exists $sec_pse{$dl{$_->dl_id}->sec_id}){
		if($sec_pse{$dl{$_->dl_id}->sec_id} != $_->pse_id){
		    $self->{Error} = "Barcode $bars_in->[0] seems to have multiple source pses for sector ".$dl{$_->dl_id}->sec_id;
		    return;
		}
	    }
	    else{
		$sec_pse{$dl{$_->dl_id}->sec_id} = $_->pse_id;
	    }
	}
	
	foreach my $sid(keys %sec_pse){
	    my $sector = GSC::Sector->get($sid);
	    $dd{$sector->sector_name} = [$pre_pse_ids->[0],   $sec_pse{$sid}];
	}
    }
    else{
	#------------------------ old way
	foreach my $pre_pse (GSC::PSE->get(pse_id => $pre_pse_ids)) {
	    my @dna;
	    
	    my @pps = $pre_pse->prior_pse_ids_recurse;
	    push @pps, $pre_pse->pse_id;
	    my @pbs = GSC::PSEBarcode->get(barcode => $bars_in->[0], pse_id => \@pps, direction => 'out');
	    unless(@pbs) {
		$self -> {'Error'} = "Could not find the data for barcode [" . $bars_in->[0] . "] for prior_pse_id [" . $pre_pse->pse_id . "].";
		return;
	    }
	    my @dps = GSC::DNAPSE->get(pse_id => \@pbs);
	    my @ss = GSC::Sector->get(sec_id => [ keys %{{ map { $_->sec_id => 1 } GSC::DNALocation->get(dl_id => \@dps) }} ]);
	    unless(@ss == 1) {
		$self -> {'Error'} = "Could not find the unique sector for barcode [" . $bars_in->[0] . "] for prior_pse_id [" . $pre_pse->pse_id . "].";
		return;
	    }
	    $dd{$ss[0]->sector_name} = [$pre_pse->pse_id, $pbs[0]->pse_id];
	}
    }
    #-------------------------
    
    foreach my $sector_name (sort keys %dd) {
	my ($prior_pse_id, $plate_creation_pse_id) = @{$dd{$sector_name}};
	my $bar_out = $bars_out->[$i];
	my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $prior_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out], $emp_id);
	my $result = $self -> Trans384To96($bars_in->[0], $plate_creation_pse_id, $new_pse_id, 'archive', uc($sector_name));
	return 0 if($result == 0);
	push(@{$pse_ids}, $new_pse_id);
	$i++;     
    }
    unless(@{$pse_ids} >= @$pre_pse_ids) {
	$self->{'Error'} = "Expected " . scalar(@{$pse_ids}) . " pse_ids created but only " . scalar(@$pre_pse_ids) . " pse_ids created!"; 
	return;
    }
    return $pse_ids;
    
} #Inoculate384to96


##########################################
# Inoculate from a 96 plate to 96 plate #
##########################################
sub Inoculate96to96 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i=0;

    
    my $pre_pse_id = $pre_pse_ids->[0];
    if(! defined $pre_pse_id) {
	$self -> {'Error'} = "Could not find a valid pre_pse_id.";
    }
    
    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);


    my $result = $self -> Trans96To96($bars_in->[0], $pre_pse_id, $new_pse_id, 'archive');
    return 0 if($result == 0);
    
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;

} #Inoculate96to96

sub CellLysis {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i=0;    
    my $pre_pse_id = $pre_pse_ids->[0];
    if(! defined $pre_pse_id) {
	$self -> {'Error'} = "Could not find a valid pre_pse_id.";
    }
    
    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);

    my $result = $self -> Trans96To96($bars_in->[0], $pre_pse_id, $new_pse_id, 'archive');
    return 0 if($result == 0);
    
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;


} #CellLysis


sub ArchiveToSubcloneTransfer {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i=0;    
    my $pre_pse_id = $pre_pse_ids->[0];
    if(! defined $pre_pse_id) {
	$self -> {'Error'} = "Could not find a valid pre_pse_id.";
    }
    
    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);

    my $result = $self -> Trans96To96($bars_in->[0], $pre_pse_id, $new_pse_id, 'archive');
    return 0 if($result == 0);
    
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;


} #ArchiveToSubcloneTransfer


sub SubcloneToSubcloneTransfer96 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i=0;    
    my $pre_pse_id = $pre_pse_ids->[0];
    if(! defined $pre_pse_id) {
	$self -> {'Error'} = "Could not find a valid pre_pse_id.";
    }
    
    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);

    my $result = $self -> Trans96To96($bars_in->[0], $pre_pse_id, $new_pse_id, 'subclone');
    return 0 if($result == 0);
    
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;


} #SubcloneToSubcloneTransfer


sub ResuspendDna {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i=0;    


    if(! defined $pre_pse_ids->[0]) {
	$self -> {'Error'} = "Could not find a valid pre_pse_id.";
    }

    foreach my $pre_pse_id (@{$pre_pse_ids}) {    
	my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
	#LSF: Skip creating the dna_pse.
	#my $result = $self -> Trans96To96($bars_in->[0], $pre_pse_id, $new_pse_id, 'sequenced_dna');
	#return 0 if($result == 0);
    
	push(@{$pse_ids}, $new_pse_id);
    
    }
    return $pse_ids;


} #ResuspendDna

sub DnaPurification {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;


    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i=0;    
    my $pre_pse_id = $pre_pse_ids->[0];
    if(! defined $pre_pse_id) {
	$self -> {'Error'} = "Could not find a valid pre_pse_id.";
    }
    
    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);

    my $result = $self -> Trans96To96($bars_in->[0], $pre_pse_id, $new_pse_id, 'subclone');
    return 0 if($result == 0);
    
    push(@{$pse_ids}, $new_pse_id);
    
    return $pse_ids;


} #DnaPurification


###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub Sequence384 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $dye_chem_id_fwd = $options->{'GetFwdDyeChemId'};
    my $dye_chem_id_rev = $options->{'GetRevDyeChemId'};
    my $primer_id_fwd = $options->{'GetFwdPrimerId'};
    my $primer_id_rev = $options->{'GetRevPrimerId'};
    my $enz_id_fwd = $options->{'GetFwdEnzId'};
    my $enz_id_rev = $options->{'GetRevEnzId'};
    my $reagent_fwd = $options->{'GetReagentNameFwd'};
    my $reagent_rev = $options->{'GetReagentNameRev'};
    
    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', 384);
    return 0 if($pt_id == 0);

    return 0 if(! defined $dye_chem_id_fwd);
    return 0 if(! defined $primer_id_fwd);
    return 0 if(! defined $enz_id_fwd);
    return 0 if(! defined $dye_chem_id_rev);
    return 0 if(! defined $primer_id_rev);
    return 0 if(! defined $enz_id_rev);
    return 0 if(! defined $reagent_fwd);
    return 0 if(! defined $reagent_rev);
    
    
    for my $i (0 .. $#{$bars_in}) {    
       if(!($bars_in->[$i] =~ /^empty/)) {
	    my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[$i]);
	    return 0 if(!$result);

	    $result = $self -> ComparePrimerReagentToAvailVector($reagent_rev, $bars_in->[$i]);
	    return 0 if(!$result);

	    my $plate_pse_ids = $self->{'GetBarocdeCreatePse'} -> xSql($bars_in->[$i]);
	    return (0) if(!defined $plate_pse_ids);
	    my $plate_pse_id = $plate_pse_ids->[0];

	    my $pre_pse_ids = $self -> {'CoreSql'} -> Process('GetPrePseForBarcode', $bars_in->[$i], 'in', $status, $ps_id);
	    return ($self->GetCoreError) if(!$pre_pse_ids);
	    
	    my $pre_pse_id = $pre_pse_ids->[0];
	    
	    $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	    return 0 if($result == 0);
	    
	    my ($sec_id_fwd, $sec_id_rev);
	    
	    if($i == 0) {
		$sec_id_fwd = $self -> {'CoreSql'} -> Process('GetSectorId', 'a1');
		return ($self->GetCoreError) if(!$sec_id_fwd);
		$sec_id_rev = $self -> {'CoreSql'} -> Process('GetSectorId', 'a2');
		return ($self->GetCoreError) if(!$sec_id_rev);
	    }
	    else {
		$sec_id_fwd = $self -> {'CoreSql'} -> Process('GetSectorId', 'b1');
		return ($self->GetCoreError) if(!$sec_id_fwd);
		$sec_id_rev = $self -> {'CoreSql'} -> Process('GetSectorId', 'b2');
		return ($self->GetCoreError) if(!$sec_id_rev);
	    }
	    
	    my $new_pse_id_fwd = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
	    return 0 if ($new_pse_id_fwd == 0);


	    $result = $self -> CreateSequenceDna($bars_in->[$i], $plate_pse_id, $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id_fwd, $new_pse_id_fwd);
	    return 0 if ($result == 0);
	    
	    
	    my $new_pse_id_rev = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
	    return 0 if ($new_pse_id_rev == 0);
	    
	    $result = $self -> CreateSequenceDna($bars_in->[$i], $plate_pse_id, $dye_chem_id_rev, $primer_id_rev, $enz_id_rev, $pt_id, $sec_id_rev, $new_pse_id_rev);
	    return 0 if ($result == 0);
	    
	    
	    push(@{$pse_ids}, $new_pse_id_fwd);
	    push(@{$pse_ids}, $new_pse_id_rev);
	}
    }

    return $pse_ids;
} #Sequence384

###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub SequenceBiomek384 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $reagent_info = $self->GetReagentInfo($options->{'Machine'}, 'plasmid');
    my $dye_chem_id_fwd = $reagent_info->{'FwdDyeChemId'};
    my $dye_chem_id_rev = $reagent_info->{'RevDyeChemId'};
    my $primer_id_fwd = $reagent_info->{'FwdPrimerId'};
    my $primer_id_rev = $reagent_info->{'RevPrimerId'};
    my $enz_id_fwd = $reagent_info->{'FwdEnzId'};
    my $enz_id_rev = $reagent_info->{'RevEnzId'};
    my $reagent_fwd = $reagent_info->{'ReagentNameFwd'};
    my $reagent_rev = $reagent_info->{'ReagentNameRev'};
    my $fwd_barcode = $reagent_info->{'ReagentBarcodeFwd'};
    my $rev_barcode= $reagent_info->{'ReagentBarcodeRev'};


    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', 384);
    return 0 if($pt_id == 0);
    
    for my $i (0 .. $#{$bars_in}) {    
	if(!($bars_in->[$i] =~ /^empty/)) {
	    my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[$i]);
	    return 0 if(!$result);

	    $result = $self -> ComparePrimerReagentToAvailVector($reagent_rev, $bars_in->[$i]);
	    return 0 if(!$result);
	    
	    my $plate_pse_ids = $self->{'GetBarocdeCreatePse'} -> xSql($bars_in->[$i]);
	    return (0) if(!defined $plate_pse_ids);
	    my $plate_pse_id = $plate_pse_ids->[0];

	    my $pre_pse_ids = $self -> {'CoreSql'} -> Process('GetPrePseForBarcode', $bars_in->[$i], 'in', $status, $ps_id);
	    return ($self->GetCoreError) if(!$pre_pse_ids);
	    
	    my $pre_pse_id = $pre_pse_ids->[0];
	    
	    $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	    return 0 if($result == 0);
	    
	    my ($sec_id_fwd, $sec_id_rev);
	    
	    if($i == 0) {
		$sec_id_fwd = $self -> {'CoreSql'} -> Process('GetSectorId', 'a1');
		return ($self->GetCoreError) if(!$sec_id_fwd);
		$sec_id_rev = $self -> {'CoreSql'} -> Process('GetSectorId', 'a2');
		return ($self->GetCoreError) if(!$sec_id_rev);
	    }
	    else {
		$sec_id_fwd = $self -> {'CoreSql'} -> Process('GetSectorId', 'b1');
		return ($self->GetCoreError) if(!$sec_id_fwd);
		$sec_id_rev = $self -> {'CoreSql'} -> Process('GetSectorId', 'b2');
		return ($self->GetCoreError) if(!$sec_id_rev);
	    }
	    
	    my $new_pse_id_fwd = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
	    return 0 if ($new_pse_id_fwd == 0);


	    $result = $self -> CreateSequenceDna($bars_in->[$i], $plate_pse_ids->[0], $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id_fwd, $new_pse_id_fwd);
	    return 0 if ($result == 0);
	    
	    
	    my $new_pse_id_rev = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
	    return 0 if ($new_pse_id_rev == 0);
	    
	    $result = $self -> CreateSequenceDna($bars_in->[$i], $plate_pse_ids->[0], $dye_chem_id_rev, $primer_id_rev, $enz_id_rev, $pt_id, $sec_id_rev, $new_pse_id_rev);
	    return 0 if ($result == 0);
	    
	    $result = $self-> InsertReagentUsedPses($fwd_barcode, $new_pse_id_fwd);
	    return 0 if(!$result);

	    $result = $self->InsertReagentUsedPses($rev_barcode, $new_pse_id_rev);
	    return 0 if(!$result);
	    push(@{$pse_ids}, $new_pse_id_fwd);
	    push(@{$pse_ids}, $new_pse_id_rev);
	}
    }

    return $pse_ids;
} #SequenceBiomek384

###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub SequenceBiomek384new {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $reagent_info = $self->GetReagentInfo($options->{'Machine'}, 'plasmid');
    my $dye_chem_id_fwd = $reagent_info->{'FwdDyeChemId'};
    my $dye_chem_id_rev = $reagent_info->{'RevDyeChemId'};
    my $primer_id_fwd = $reagent_info->{'FwdPrimerId'};
    my $primer_id_rev = $reagent_info->{'RevPrimerId'};
    my $enz_id_fwd = $reagent_info->{'FwdEnzId'};
    my $enz_id_rev = $reagent_info->{'RevEnzId'};
    my $reagent_fwd = $reagent_info->{'ReagentNameFwd'};
    my $reagent_rev = $reagent_info->{'ReagentNameRev'};
    my $fwd_barcode = $reagent_info->{'ReagentBarcodeFwd'};
    my $rev_barcode= $reagent_info->{'ReagentBarcodeRev'};


    for my $i (0 .. $#{$bars_in}) {    
	if(!($bars_in->[$i] =~ /^empty/)) {
	    my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[$i]);
	    return 0 if(!$result);

	    $result = $self -> ComparePrimerReagentToAvailVector($reagent_rev, $bars_in->[$i]);
	    return 0 if(!$result);
	    
	    my $plate_pse_ids = $self->{'GetBarocdeCreatePse'} -> xSql($bars_in->[$i]);
	    return (0) if(!defined $plate_pse_ids);
	    my $plate_pse_id = $plate_pse_ids->[0];

	    my $pre_pse_ids = $self -> {'CoreSql'} -> Process('GetPrePseForBarcode', $bars_in->[$i], 'in', $status, $ps_id);
	    return ($self->GetCoreError) if(!$pre_pse_ids);
	    
	    my $pre_pse_id = $pre_pse_ids->[0];
	    
	    $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	    return 0 if($result == 0);
	    
	    my $new_pse_id_fwd = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
	    return 0 if ($new_pse_id_fwd == 0);

	    my $new_pse_id_rev = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
	    return 0 if ($new_pse_id_rev == 0);

            
            my $lol =  $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($bars_in->[$i], $plate_pse_ids->[0]);
            my @fwd_dnas;
            my @rev_dnas;

            foreach my $row (@{$lol}) {
                my $sub_id = $row->[0];
                my $well_96 = $row->[1];
                my $pl_id = $row->[2];
                
                my $pl_id_fwd;
                my $pl_id_rev;
                if($i == 0) {
                    my $well_384_fwd = &ConvertWell::To384 ($well_96, 'a1');
                    $pl_id_fwd = GSC::DNALocation->get(sec_id => 1,
                                                       location_name => $well_384_fwd,
                                                       location_type  => '384 well plate')->dl_id;
                    
                    my $well_384_rev = &ConvertWell::To384 ($well_96, 'a2');
                    $pl_id_rev = GSC::DNALocation->get(sec_id => 2,
                                                       location_name => $well_384_rev,
                                                       location_type  => '384 well plate')->dl_id;
                }
                else {
                    my $well_384_fwd = &ConvertWell::To384 ($well_96, 'b1');
                    $pl_id_fwd = GSC::DNALocation->get(sec_id => 3,
                                                       location_name => $well_384_fwd,
                                                       location_type  => '384 well plate')->dl_id;
                    
                    my $well_384_rev = &ConvertWell::To384 ($well_96, 'b2');
                    $pl_id_rev = GSC::DNALocation->get(sec_id => 4,
                                                       location_name => $well_384_rev,
                                                       location_type  => '384 well plate')->dl_id;
 
                }
                
                # insert subclone into table
#                my $seq_id_fwd = $self->GetNextSeqdnaId;
#                $result = $self->InsertSequencedDnas($sub_id, $primer_id_fwd, $dye_chem_id_fwd, $enz_id_fwd, $seq_id_fwd, $new_pse_id_fwd, $pl_id_fwd);
#                return 0 if(!$result);
                push(@fwd_dnas, [pri_id => $primer_id_fwd, 
                                 dc_id => $dye_chem_id_fwd,
                                 enz_id => $enz_id_fwd,
                                 parent_dna_id => $sub_id,
                                 pse_id => $new_pse_id_fwd,
                                 dl_id => $pl_id_fwd]);

                

#                my $seq_id_rev = $self->GetNextSeqdnaId;
#                $result = $self->InsertSequencedDnas($sub_id, $primer_id_rev, $dye_chem_id_rev, $enz_id_rev, $seq_id_rev, $new_pse_id_rev, $pl_id_rev);
#                return 0 if(!$result);
 

                push(@rev_dnas, [pri_id => $primer_id_rev, 
                                 dc_id => $dye_chem_id_rev,
                                 enz_id => $enz_id_rev,
                                 parent_dna_id => $sub_id,
                                 pse_id => $new_pse_id_rev,
                                 dl_id => $pl_id_rev]);
               

            }                
  
            my @created_fwd_dnas = GSC::SeqDNA->bulk_create(\@fwd_dnas);
            unless(@created_fwd_dnas == 96) {
                $self->{'Error'} = "SeqSql -> Failed bulk create.";
                return 0;
            }
            my @created_rev_dnas = GSC::SeqDNA->bulk_create(\@rev_dnas);
            unless(@created_rev_dnas == 96) {
                $self->{'Error'} = "SeqSql -> Failed bulk create.";
                return 0;
            }
	    
	    $result = $self-> InsertReagentUsedPses($fwd_barcode, $new_pse_id_fwd);
	    return 0 if(!$result);

	    $result = $self->InsertReagentUsedPses($rev_barcode, $new_pse_id_rev);
	    return 0 if(!$result);
	    push(@{$pse_ids}, $new_pse_id_fwd);
	    push(@{$pse_ids}, $new_pse_id_rev);
	}
    }

    return $pse_ids;
} #SequenceBiomek384


###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub SequenceBiomek1to1_384 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $reagent_info = $self->GetReagentInfo($options->{'Machine'}, 'plasmid');
    my $dye_chem_id_fwd = $reagent_info->{'FwdDyeChemId'};
    my $dye_chem_id_rev = $reagent_info->{'RevDyeChemId'};
    my $primer_id_fwd = $reagent_info->{'FwdPrimerId'};
    my $primer_id_rev = $reagent_info->{'RevPrimerId'};
    my $enz_id_fwd = $reagent_info->{'FwdEnzId'};
    my $enz_id_rev = $reagent_info->{'RevEnzId'};
    my $reagent_fwd = $reagent_info->{'ReagentNameFwd'};
    my $reagent_rev = $reagent_info->{'ReagentNameRev'};
    my $fwd_barcode = $reagent_info->{'ReagentBarcodeFwd'};
    my $rev_barcode= $reagent_info->{'ReagentBarcodeRev'};


    my @sectors= qw(a1 a2 b1 b2);

    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', 384);
    return 0 if($pt_id == 0);
    
    for my $i (0 .. $#{$bars_in}) {    
	if(!($bars_in->[$i] =~ /^empty/)) {

	

	    my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[$i]);
	    return 0 if(!$result);

	    $result = $self -> ComparePrimerReagentToAvailVector($reagent_rev, $bars_in->[$i]);
	    return 0 if(!$result);
	
    
	    my $pre_pse_ids = $self -> {'CoreSql'} -> Process('GetPrePseForBarcode', $bars_in->[$i], 'out', $status, $ps_id);
	    return ($self->GetCoreError) if(!$pre_pse_ids);
	    
	    foreach my $pre_pse_id (@$pre_pse_ids) {
		
		$result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
		return 0 if($result == 0);
		
		my ($sec_id_fwd) = $self->{'dbh'} -> selectrow_array(qq/select distinct sec_id from dna_location dl, dna_pse dp where dp.dl_id = dl.dl_id
								   and dp.pse_id = '$pre_pse_id'/);
		return ($self->GetCoreError) if(!$sec_id_fwd);
		
		my $sec_id_rev = $sec_id_fwd;

	    
		my $new_pse_id_fwd = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], [], $emp_id);
		return 0 if ($new_pse_id_fwd == 0);


		$result = $self -> CreateSequenceDna($bars_in->[$i], $pre_pse_id, $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id_fwd, $new_pse_id_fwd);
		return 0 if ($result == 0);
	    
		
		my $new_pse_id_rev = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], [$bars_out->[0]], $emp_id);
		return 0 if ($new_pse_id_rev == 0);
	    
		$result = $self -> CreateSequenceDna($bars_in->[$i], $pre_pse_id, $dye_chem_id_rev, $primer_id_rev, $enz_id_rev, $pt_id, $sec_id_rev, $new_pse_id_rev);
		return 0 if ($result == 0);
	    
		$result = $self-> InsertReagentUsedPses($fwd_barcode, $new_pse_id_fwd);
		return 0 if(!$result);
		
		$result = $self->InsertReagentUsedPses($rev_barcode, $new_pse_id_rev);
		return 0 if(!$result);
		
		push(@{$pse_ids}, $new_pse_id_fwd);
		push(@{$pse_ids}, $new_pse_id_rev);
	    }
	}
    }

    return $pse_ids;
} #SequenceBiomek1to1_384

###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub Sequence96 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
    my $dye_chem_id_fwd = $options->{'GetFwdDyeChemId'};
    my $dye_chem_id_rev = $options->{'GetRevDyeChemId'};
    my $primer_id_fwd = $options->{'GetFwdPrimerId'};
    my $primer_id_rev = $options->{'GetRevPrimerId'};
    my $enz_id_fwd = $options->{'GetFwdEnzId'};
    my $enz_id_rev = $options->{'GetRevEnzId'};
    my $reagent_fwd = $options->{'GetReagentNameFwd'};
    my $reagent_rev = $options->{'GetReagentNameRev'};

    return 0 if(! defined $dye_chem_id_fwd);
    return 0 if(! defined $primer_id_fwd);
    return 0 if(! defined $enz_id_fwd);
    return 0 if(! defined $dye_chem_id_rev);
    return 0 if(! defined $primer_id_rev);
    return 0 if(! defined $enz_id_rev);
    return 0 if(! defined $reagent_fwd);
    return 0 if(! defined $reagent_rev);
 
    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', 96);
    return 0 if($pt_id == 0);
    
    my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[0]);
    return 0 if(!$result);
    
    $result = $self -> ComparePrimerReagentToAvailVector($reagent_rev, $bars_in->[0]);
    return 0 if(!$result);
	    
    my $plate_pse_ids = $self->{'GetBarocdeCreatePse'} -> xSql($bars_in->[0]);
    return (0) if(!defined $plate_pse_ids);
    my $plate_pse_id = $plate_pse_ids->[0];
    
    my $pre_pse_ids = $self -> {'CoreSql'} -> Process('GetPrePseForBarcode', $bars_in->[0], 'in', $status, $ps_id);
    return ($self->GetCoreError) if(!$pre_pse_ids);
    
    my $pre_pse_id = $pre_pse_ids->[0];
	    
    $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
    return 0 if($result == 0);
    
    my $sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', 'a1');
    return ($self->GetCoreError) if(!$sec_id);
    
    
    my $new_pse_id_fwd = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bars_out->[0]], $emp_id);
    return 0 if ($new_pse_id_fwd == 0);


    $result = $self -> CreateSequenceDna($bars_in->[0], $plate_pse_id, $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id, $new_pse_id_fwd);
    return 0 if ($result == 0);
    
    my $new_pse_id_rev = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bars_out->[1]], $emp_id);
    return 0 if ($new_pse_id_rev == 0);
    
    $result = $self -> CreateSequenceDna($bars_in->[0], $plate_pse_id, $dye_chem_id_rev, $primer_id_rev, $enz_id_rev, $pt_id, $sec_id, $new_pse_id_rev);
    return 0 if ($result == 0);
    
    
    push(@{$pse_ids}, $new_pse_id_fwd);
    push(@{$pse_ids}, $new_pse_id_rev);
    
    return $pse_ids;
} #Sequence96

###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub SequenceBiomek96 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';

    my $reagent_info = $self->GetReagentInfo($options->{'Machine'}, 'plasmid');
    my $dye_chem_id_fwd = $reagent_info->{'FwdDyeChemId'};
    my $dye_chem_id_rev = $reagent_info->{'RevDyeChemId'};
    my $primer_id_fwd = $reagent_info->{'FwdPrimerId'};
    my $primer_id_rev = $reagent_info->{'RevPrimerId'};
    my $enz_id_fwd = $reagent_info->{'FwdEnzId'};
    my $enz_id_rev = $reagent_info->{'RevEnzId'};
    my $reagent_fwd = $reagent_info->{'ReagentNameFwd'};
    my $reagent_rev = $reagent_info->{'ReagentNameRev'};
    my $fwd_barcode = $reagent_info->{'ReagentBarcodeFwd'};
    my $rev_barcode= $reagent_info->{'ReagentBarcodeRev'};

 
    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', 96);
    return 0 if($pt_id == 0);
    
    my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[0]);
    return 0 if(!$result);
    
    $result = $self -> ComparePrimerReagentToAvailVector($reagent_rev, $bars_in->[0]);
    return 0 if(!$result);
	    
	    
    my $plate_pse_ids = $self->{'GetBarocdeCreatePse'} -> xSql($bars_in->[0]);
    return (0) if(!defined $plate_pse_ids);
    my $plate_pse = $plate_pse_ids->[0];
    
    my $pre_pse_ids = $self -> {'CoreSql'} -> Process('GetPrePseForBarcode', $bars_in->[0], 'in', $status, $ps_id);
    return ($self->GetCoreError) if(!$pre_pse_ids);
    
    my $pre_pse_id = $pre_pse_ids->[0];
	    
    $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
    return 0 if($result == 0);
    
    my $sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', 'a1');
    return ($self->GetCoreError) if(!$sec_id);
    
    
    my $new_pse_id_fwd = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bars_out->[0]], $emp_id);
    return 0 if ($new_pse_id_fwd == 0);


    $result = $self -> CreateSequenceDna($bars_in->[0], $plate_pse, $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id, $new_pse_id_fwd);
    return 0 if ($result == 0);
    
    my $new_pse_id_rev = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bars_out->[1]], $emp_id);
    return 0 if ($new_pse_id_rev == 0);
    
    $result = $self -> CreateSequenceDna($bars_in->[0], $plate_pse, $dye_chem_id_rev, $primer_id_rev, $enz_id_rev, $pt_id, $sec_id, $new_pse_id_rev);
    return 0 if ($result == 0);
    
    $result = $self-> InsertReagentUsedPses($fwd_barcode, $new_pse_id_fwd);
    return 0 if(!$result);
    
    $result = $self->InsertReagentUsedPses($rev_barcode, $new_pse_id_rev);
    return 0 if(!$result);
    
    push(@{$pse_ids}, $new_pse_id_fwd);
    push(@{$pse_ids}, $new_pse_id_rev);
    
    return $pse_ids;
} #SequenceBiomek96


###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub Sequence384m13 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $plate_type = '384';
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $dye_chem_id_fwd = $options->{'GetFwdDyeChemId'};
    my $primer_id_fwd = $options->{'GetFwdPrimerId'};
    my $enz_id_fwd = $options->{'GetFwdEnzId'};
    my $reagent = $options->{'GetReagentName'};
    
    return 0 if(! defined $dye_chem_id_fwd);
    return 0 if(! defined $primer_id_fwd);
    return 0 if(! defined $enz_id_fwd);
    return 0 if(! defined $reagent);
 
    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', 384);
    return 0 if($pt_id == 0);

    for my $i (0 .. $#{$bars_in}) {    
	
	if(!($bars_in->[$i] =~ /^empty/)) {
	    my $result = $self -> ComparePrimerReagentToAvailVector($reagent, $bars_in->[$i]);
	    return 0 if(!$result);
	    
	    my $pre_pse_ids = $self -> {'CoreSql'} -> Process('GetPrePseForBarcode', $bars_in->[$i], 'out', $status, $ps_id);
	    return ($self->GetCoreError) if(!$pre_pse_ids);
	    
	    my $pre_pse_id = $pre_pse_ids->[0];
	    
	    $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	    return 0 if($result == 0);
	    
	    my ($sec_id);
	    if($i == 0) {
		$sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', 'a1');
	    }
	    elsif($i == 1) {
		$sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', 'a2');
	    }
	    elsif($i == 2) {
		$sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', 'b1');
	    }
	    elsif($i == 3) {
		$sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', 'b2');
	    }
	    return ($self->GetCoreError) if(!$sec_id);
	    
	    my $new_pse_id_fwd = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
	    return 0 if ($new_pse_id_fwd == 0);
	    
	    
	    $result = $self -> CreateSequenceDna($bars_in->[$i], $pre_pse_id, $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id, $new_pse_id_fwd);
	    return 0 if ($result == 0);
	    
	    
	    push(@{$pse_ids}, $new_pse_id_fwd);
	}
   }
    
    return $pse_ids;
} #Sequence384m13


###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub SequenceBiomek384m13 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $plate_type = '384';
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';

    my $reagent_info = $self->GetReagentInfo($options->{'Machine'}, 'm13');
    my $dye_chem_id_fwd = $reagent_info->{'FwdDyeChemId'};
    my $primer_id_fwd = $reagent_info->{'FwdPrimerId'};
    my $enz_id_fwd = $reagent_info->{'FwdEnzId'};
    my $reagent_fwd = $reagent_info->{'ReagentNameFwd'};
    my $fwd_barcode = $reagent_info->{'ReagentBarcodeFwd'};

 
    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', 384);
    return 0 if($pt_id == 0);

    for my $i (0 .. $#{$bars_in}) {    
	
	if(!($bars_in->[$i] =~ /^empty/)) {
	    my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[$i]);
	    return 0 if(!$result);
	    
	    my $pre_pse_ids = $self -> {'CoreSql'} -> Process('GetPrePseForBarcode', $bars_in->[$i], 'out', $status, $ps_id);
	    return ($self->GetCoreError) if(!$pre_pse_ids);
	    
	    my $pre_pse_id = $pre_pse_ids->[0];
	    
	    $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	    return 0 if($result == 0);
	    
	    my ($sec_id);
	    if($i == 0) {
		$sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', 'a1');
	    }
	    elsif($i == 1) {
		$sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', 'a2');
	    }
	    elsif($i == 2) {
		$sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', 'b1');
	    }
	    elsif($i == 3) {
		$sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', 'b2');
	    }
	    return ($self->GetCoreError) if(!$sec_id);
	    
	    my $new_pse_id_fwd = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
	    return 0 if ($new_pse_id_fwd == 0);
	    
	    
	    $result = $self -> CreateSequenceDna($bars_in->[$i], $pre_pse_id, $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id, $new_pse_id_fwd);
	    return 0 if ($result == 0);
	    
	    $result = $self-> InsertReagentUsedPses($fwd_barcode, $new_pse_id_fwd);
	    return 0 if(!$result);
    
 	    
	    push(@{$pse_ids}, $new_pse_id_fwd);
	}
   }
    
    return $pse_ids;
} #SequenceBiomek384m13



###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub Sequence96m13 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $plate_type = '96';
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $dye_chem_id_fwd = $options->{'GetFwdDyeChemId'};
    my $primer_id_fwd = $options->{'GetFwdPrimerId'};
    my $enz_id_fwd = $options->{'GetFwdEnzId'};
    my $reagent = $options->{'GetReagentName'};

    return 0 if(! defined $dye_chem_id_fwd);
    return 0 if(! defined $primer_id_fwd);
    return 0 if(! defined $enz_id_fwd);
    return 0 if(! defined $reagent);



    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', 96);
    return 0 if($pt_id == 0);

    my $result = $self -> ComparePrimerReagentToAvailVector($reagent, $bars_in->[0]);
    return 0 if(!$result);
    
    my $pre_pse_ids = $self -> {'CoreSql'} -> Process('GetPrePseForBarcode', $bars_in->[0], 'out', $status, $ps_id);
    return ($self->GetCoreError) if(!$pre_pse_ids);
    
    my $pre_pse_id = $pre_pse_ids->[0];
	    
    $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
    return 0 if($result == 0);
    
    my $sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', 'a1');
    return ($self->GetCoreError) if(!$sec_id);
    
    
    my $new_pse_id_fwd = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bars_out->[0]], $emp_id);
    return 0 if ($new_pse_id_fwd == 0);


    $result = $self -> CreateSequenceDna($bars_in->[0], $pre_pse_id, $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id, $new_pse_id_fwd);
    return 0 if ($result == 0);
    
    push(@{$pse_ids}, $new_pse_id_fwd);

    return $pse_ids;
} #Sequence96m13


###########################################################
# Execute an Initial Processes step for creating archives #
###########################################################
sub SequenceBiomek96m13 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;
    
    my ($sql);
    
    my $pse_ids = [];
    my $plate_type = '96';
    my $status = 'inprogress';
    my $update_status = 'completed';
    my $update_result = 'successful';


    my $reagent_info = $self->GetReagentInfo($options->{'Machine'}, 'm13');
    my $dye_chem_id_fwd = $reagent_info->{'FwdDyeChemId'};
    my $primer_id_fwd = $reagent_info->{'FwdPrimerId'};
    my $enz_id_fwd = $reagent_info->{'FwdEnzId'};
    my $reagent_fwd = $reagent_info->{'ReagentNameFwd'};
    my $fwd_barcode = $reagent_info->{'ReagentBarcodeFwd'};

    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', 96);
    return 0 if($pt_id == 0);

    my $result = $self -> ComparePrimerReagentToAvailVector($reagent_fwd, $bars_in->[0]);
    return 0 if(!$result);
    
    my $pre_pse_ids = $self -> {'CoreSql'} -> Process('GetPrePseForBarcode', $bars_in->[0], 'out', $status, $ps_id);
    return ($self->GetCoreError) if(!$pre_pse_ids);
    
    my $pre_pse_id = $pre_pse_ids->[0];
	    
    $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
    return 0 if($result == 0);
    
    my $sec_id = $self -> {'CoreSql'} -> Process('GetSectorId', 'a1');
    return ($self->GetCoreError) if(!$sec_id);
    
    
    my $new_pse_id_fwd = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bars_out->[0]], $emp_id);
    return 0 if ($new_pse_id_fwd == 0);


    $result = $self -> CreateSequenceDna($bars_in->[0], $pre_pse_id, $dye_chem_id_fwd, $primer_id_fwd, $enz_id_fwd, $pt_id, $sec_id, $new_pse_id_fwd);
    return 0 if ($result == 0);
 	
    $result = $self-> InsertReagentUsedPses($fwd_barcode, $new_pse_id_fwd);
    return 0 if(!$result);
    
   
    push(@{$pse_ids}, $new_pse_id_fwd);

    return $pse_ids;
} #SequenceBiomek96m13



sub RearraySequencePlates {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;
    
    my $pse_ids = [];
    my $plate_type = '384';
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
    
    my @sectors =  qw(a1 a2 b1 b2);
 
    for my $i (0 .. $#{$bars_in}) {    
	if(!($bars_in->[$i] =~ /^empty/)) {
	    
	    my $sec_id =  $self -> {'CoreSql'} -> Process('GetSectorId', $sectors[$i]);
	    return ($self->GetCoreError) if(!$sec_id);
	    
	    my $pre_pse_ids = $self -> {'CoreSql'} -> Process('GetPrePseForBarcode', $bars_in->[$i], 'in', $status, $ps_id);
	    return 0 if(!$pre_pse_ids);
	    
	    my $pre_pse_id = $pre_pse_ids->[0];
	    
	    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
	    
	    my $result = $self -> Trans96To384($bars_in->[$i], $pre_pse_id, $new_pse_id, $sec_id, 'sequenced_dna');
	    return 0 if($result == 0);

	    push(@{$pse_ids}, $new_pse_id);
    
	}
    }
    
    return $pse_ids;
} #RearraySequencePlates

sub RearrayDNAPlates {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;
    
    my $pse_ids = [];
    my $plate_type = '384';
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $status = 'inprogress';
    
    my @sectors =  qw(a1 a2 b1 b2);
 
    for my $i (0 .. $#{$bars_in}) {    
	if(!($bars_in->[$i] =~ /^empty/)) {
	    
	    my $sec_id =  $self -> {'CoreSql'} -> Process('GetSectorId', $sectors[$i]);
	    return ($self->GetCoreError) if(!$sec_id);
	    
	    my $pre_pse_ids = $self -> {'CoreSql'} -> Process('GetPrePseForBarcode', $bars_in->[$i], 'in', $status, $ps_id);
	    return 0 if(!$pre_pse_ids);
	    
	    my $pre_pse_id = $pre_pse_ids->[0];
	    
	    my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[$i], $bars_out, $emp_id);
	    
	    my $result = $self -> Trans96To384($bars_in->[$i], $pre_pse_id, $new_pse_id, $sec_id, 'archive');
	    return 0 if($result == 0);

	    push(@{$pse_ids}, $new_pse_id);
    
	}
    }
    
    return $pse_ids;
} #RearraySequencePlates

=head1 FailBarcode

############################
# Fail barcode at any step #
############################
select 
	distinct pb.bs_barcode 
from 
	pse_equipment_informations pei, 
	pse_barcodes pb, 
	process_step_executions pse 
where 
	pei.pse_pse_id = pse.pse_id 
and  
	pei.pse_pse_id = pb.pse_pse_id 
and
	pse.psesta_pse_status = 'inprogress'
and 
	pei.equinf_bs_barcode = '0j00ae' 
and 
	direction = 'in'
=cut

sub FailBarcode {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pses) = @_;
    my $dbh = $self ->{'dbh'};
    my $schema = $self->{'Schema'};
  
    my $type = 0;
    my %quadrant;
    
    my $data_options = $options->{'Data'};
    if(defined $data_options) {
	
	foreach my $pso_id (keys %{$data_options}) {
	    my $info = $data_options -> {$pso_id};
	    if(defined $info) {
		my $sql = "select OUTPUT_DESCRIPTION from process_step_outputs where pso_id = '$pso_id'";
		my $desc = Query($dbh, $sql);
		$quadrant{$desc} = $$info;
		$type = 384;
	    }
	}
    }
    
    my $status;
    my $sql;

    foreach my $pse_id (@{$pses}) {
	
	$status = 'fail';
	
	if($type == 384) {
	    
	    $sql = "select distinct UPPER(sector_name) from sectors, archives, archives_pses arx,
                    plate_locations, subclones_pses scx, subclones sc, plate_types
                    where arx.pse_pse_id = '$pse_id' and arx.arc_arc_id = arc_id and arc_id = sc.arc_arc_id and 
                    sub_sub_id = sub_id and pl_pl_id = pl_id and sec_sec_id = sec_id and pt_pt_id = pt_id and well_count = '384'";
	    
	    my $sector = Query($dbh, $sql);
	    
	    if(! defined $sector) {
		$sql = "select distinct UPPER(sector_name) from sectors, plate_locations,  subclones_pses, plate_types  where pse_pse_id = '$pse_id' and pl_pl_id = pl_id and sec_sec_id = sec_id  and pt_pt_id = pt_id and well_count = '384'";
		$sector = Query($dbh, $sql);
		
		if(! defined $sector) {
		    $sql = "select distinct UPPER(sector_name) from sectors, plate_locations,  seq_dna_pses, plate_types where pse_pse_id = '$pse_id' and pl_pl_id = pl_id and sec_sec_id = sec_id  and pt_pt_id = pt_id and well_count = '384'";
		    $sector = Query($dbh, $sql);
		    
		}
	    }

           if($quadrant{$sector} eq 'pass') {
                $status = 'pass';
           }
       }

       if($status eq 'fail') {
            my $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'unsuccessful', $pse_id);
            return 0 if($result == 0);
       }

   }
	

   if($bars_in->[0] =~ /^0j/) {
     $sql = <<SQL;
select 
	distinct pb.bs_barcode 
from 
	pse_equipment_informations pei, 
	pse_barcodes pb, 
	process_step_executions pse 
where 
	pei.pse_pse_id = pse.pse_id 
and  
	pei.pse_pse_id = pb.pse_pse_id 
and
	pse.psesta_pse_status = 'inprogress'
and 
	pei.equinf_bs_barcode = '$bars_in->[0]' 
and 
	direction = 'in'
SQL
	my $barcode = Query($dbh, $sql);
	if($barcode) {
	  $bars_in->[0] = $barcode;	
	}
   }

    my $new_pse_id = $self -> {'CoreSql'} -> BarcodeProcessEvent($ps_id, $bars_in->[0], [$bars_out->[1]], 'completed', 'successful', $emp_id, undef, $pses->[0]);
    return 0 if ($new_pse_id == 0);

    return [$new_pse_id];
} #FailBarcode


##########################################
# Abandone a barcode at any process step #
##########################################
sub AbandonBarcode {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pses) = @_;
    my $dbh = $self ->{'dbh'};
    my $schema = $self->{'Schema'};
  
    my $type = 0;
    my %quadrant;

    my $data_options = $options->{'Data'};
    if(defined $data_options) {
	
	foreach my $pso_id (keys %{$data_options}) {
	    my $info = $data_options -> {$pso_id};
	    if(defined $info) {
		my $sql = "select OUTPUT_DESCRIPTION from process_step_outputs where pso_id = '$pso_id'";
		my $desc = Query($dbh, $sql);
		$quadrant{$desc} = $$info;
		$type = 384;
	    }
	}
    }
    
    my $status;
    my $sql;
    foreach my $pse_id (@{$pses}) {

	$status = 'abandoned';
	
	if($type == 384) {
	    
	    $sql = "select distinct UPPER(sector_name) from sectors, archives, archives_pses arx,
                    plate_locations, subclones_pses scx, subclones sc, plate_types
                    where arx.pse_pse_id = '$pse_id' and arx.arc_arc_id = arc_id and arc_id = sc.arc_arc_id and 
                    sub_sub_id = sub_id and pl_pl_id = pl_id and sec_sec_id = sec_id and pt_pt_id = pt_id and well_count = '384'";
	    
	    my $sector = Query($dbh, $sql);
	    
	    if(! defined $sector) {
		$sql = "select distinct UPPER(sector_name) from sectors, plate_locations, 
                        subclones_pses, plate_types 
                        where pse_pse_id = '$pse_id' and pl_pl_id = pl_id and sec_sec_id = sec_id 
                        and pt_pt_id = pt_id and well_count = '384'";
		$sector = Query($dbh, $sql);
		
		if(! defined $sector) {
		    $sql = "select distinct UPPER(sector_name) from sectors, plate_locations, 
                            seq_dna_pses, plate_types 
                            where pse_pse_id = '$pse_id' and pl_pl_id = pl_id and sec_sec_id = sec_id 
                            and pt_pt_id = pt_id and well_count = '384'";
		    $sector = Query($dbh, $sql);
		    
		}
	    }


	    if($quadrant{$sector} eq 'pass') {
		$status = 'pass';
	    }
	}
	
	if($status eq 'abandoned') {
            my $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'abandoned', 'terminated', $pse_id);
 	    return 0 if($result == 0);
	}
	
    }
	
 
    my $new_pse_id = $self -> {'CoreSql'} -> BarcodeProcessEvent($ps_id, $bars_in->[0], [$bars_out->[1]], 'completed', 'successful', $emp_id, undef, $pses->[0]);
    return 0 if ($new_pse_id == 0);

    return [$new_pse_id];
} #Abandoned



############################################################################################
#                                                                                          #
#                    Post Confirm Subrotine Processes                                      #
#                                                                                          #
############################################################################################


sub AutoAbandonAgarPlates {

    my ($self, $pses) = @_;

    

    my $barcode = Query($self->{'dbh'}, "select distinct bs_barcode from pse_barcodes where direction = 'in' and pse_pse_id = '$pses->[0]'");
    my $purpose = $self->{'CheckClonePurpose'} -> xSql($barcode);
    $purpose = 'genome' unless($purpose);
    if($purpose ne 'genome') {

	my $project_info = $self->{'GetProjectTargetFromAgarPlate'} -> xSql($barcode);
	my $project_id = $project_info->[0][0];
	my $target = $project_info->[0][1];
	
	
	if(defined $project_id) {
	    
	    my $lig_id = $self->{'GetLigIdFromBarcode'} -> xSql($barcode);
	    my $qc_info = $self->{'CheckQcStatusForLigation'} -> xSql($lig_id);
	    my $picked96 =1;
	    if($qc_info->[0][0] eq 'yes') {
		my $picked96 = $self->{'GetNumbersPickedForLigation'} -> xSql($lig_id, 'Plasmid Picking', '96 archive plate');
		if($picked96 == 0) {
		    return 1;
		}	
		else {
		    $picked96=1;
		}
	    }
	    
	    my $picked_archives = $self->{'GetNumbersPickedForProject'} -> xSql($project_id);		    
	    $picked_archives = $#{$picked_archives}+1;
	    
	    my $arcs2pick = ($target - $picked_archives);
	    
	    if(($arcs2pick <= 0) && ($picked96 == 1))  {
		$self -> {'ProjectAgarPlates_old'} = LoadSql($self->{'dbh'}, "select pse.pse_id from process_step_executions pse, process_steps,
                                                             ligations, fractions, clone_growths, clone_growths_libraries, clones, 
                                                             clones_projects, dna_pse lgx
                                                             where 
                                                                 lgx.pse_id = pse.pse_id and 
                                                                 ps_ps_id = ps_id and 
                                                                 lgx.dna_id = lig_id and 
                                                                 fra_id = fra_fra_id and 
                                                                 fractions.cl_cl_id = clone_growths_libraries.cl_cl_id and
                                                                 cg_id = clone_growths_libraries.cg_cg_id 
                                                                 and clone_growths.clo_clo_id = clo_id and 
                                                                 clones_projects.clo_clo_id = clo_id and 
                                                                 project_project_id = ? and 
                                                                 (bp_barcode_prefix = '11' or bp_barcode_prefix_input = '11') and
                                                                 psesta_pse_status = 'inprogress'", 'List');
		$self -> {'ProjectAgarPlates'} = LoadSql($self->{'dbh'}, "select distinct pb1.pse_pse_id from process_steps ps, dna_pse dp, pse_barcodes pb, process_step_executions pse, pse_barcodes pb1 where
ps.ps_id = pse.ps_ps_id and (ps.bp_barcode_prefix = '11' or ps.bp_barcode_prefix_input = '11') and
pb.bs_barcode = pb1.bs_barcode and pb1.pse_pse_id = pse.pse_id and 
pse.psesta_pse_status = 'inprogress' and 
pb.bs_barcode like '11%' and pb.pse_pse_id = dp.pse_id and dp.dna_id in (
select dr.dna_id from dna_relationship dr where dtr_id in (select dtr_id from dna_type_relationship where dna_type = 'ligation')
start with dr.dna_id in (select clo_clo_id from clones_projects cl where project_project_id = ?)
connect by prior dr.dna_id = dr.parent_dna_id)", 'List');
	    
	    
	    
		my $abpses = $self -> {'ProjectAgarPlates'} -> xSql($project_id);
		
		if(defined $abpses->[0]) {
		    
		    foreach my $pse_id (@{$abpses}) {
		      #LSF: Check to make sure the out of the $pse_id barcode is ligation "11" prefix.
		      next if(grep { $_->barcode !~ /^11/ } GSC::PSEBarcode->get(pse_id => $pse_id, direction => "out"));
		      my $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'abandoned', 'terminated', $pse_id);
		      if($result == 0) {
			  $self->GetCoreError;
			  return 0;
		      }		      
		    }
		}
	    }
	}
    }
    return 1;
} #AutoAbandonAgarPlates



sub CompletePses {

    my ($self, $pses) = @_;

    foreach my $pse_id (@{$pses}) {
	
	my $result = $self -> {'CoreSql'} -> Process('UpdatePse', 'completed', 'successful', $pse_id);
	return 0 if($result == 0);
    }

    return 1;
    
}


############################################################################################
#                                                                                          #
#                      Information Retrevial Subrotines                                    #
#                                                                                          #
############################################################################################
##############################################
# Get a lig_id from pse_id in ligations_pses #
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

########################################################
# Get an arc_id from a pse in the subclones_pses table #
########################################################
sub GetArcIdFromPseInSubPses {

    my ($self, $pse_id) = @_;

    my $arc_id = $self->{'GetArcIdFromPseInSubPses'} -> xSql($pse_id);
    
    if(defined $arc_id) {
	return $arc_id;
    }

    $self->{'Error'} = "$pkg: GetArcIdFromPseInSubPses() -> Could not derive arc_id from pse_id.";
    return 0;
} #GetArcIdFromPseInSubPses



#######################################
# Get Next Archive Number for a group #
#######################################
sub GetNextArchiveNumber {

    my ($self, $group) = @_;
    my $sql;
    my $NewArchiveNumber = 0;
    my $result = 0;
    my $dbh = $self ->{'dbh'};
    my $schema = $self->{'Schema'};
#   my $db_query;
#    if($schema eq 'tlakanen') {
#	$db_query = $dbh->prepare(q{
#	    BEGIN 
#		:arch_num := tlakanen.ArchiveNumber.GetNextArchiveNumber(:group); 
#	    END;
#	    
#	});
#    }
#    else {
	my $db_query = $dbh->prepare(q{
	    BEGIN 
		:arch_num := gsc.ArchiveNumber.GetNextArchiveNumber(:group); 
	    END;
	    
	});

#    }
	
	
    my $db_answer;		
#my $arc_id = $self -> GetNextArcId;
#		return 0 if(!$arc_id);
		

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
    
		
####################################
# Get the well name from the pl_id #
####################################    
sub GetWellNameFromPlId {

    my ($self, $pl_id) = @_;

    $self -> {'GetWellNameFromPlId'} = new Load($self->{'dbh'}, "select well_name from plate_locations where pl_id = ?", 'Single');

    my $well =  $self -> {'GetWellNameFromPlId'} -> xSql($pl_id);
		
    if(defined $well) {
	return $well;
    }

    $self->{'Error'} = "$pkg: GetWellNameFromPlId() -> Could not determine well_name for $pl_id";
} #GetWellNameFromPlId


##############################
# Get Archive id from pse id #
##############################
sub GetArchiveFromPse {

    my ($self, $pse_id) = @_;
       
   my $arc_id = $self->{'GetArchiveFromPse'} -> xSql($pse_id);
    if ($arc_id != 0) {
	return $arc_id;
    }
    $self->{'Error'} = "$pkg: GetArchiveFromPse() -> Could not find an archive for pse_id = $pse_id.";

    return 0;
} #GetArchiveFromPse

sub GetReagentNameRev {
    
   my ($self, $barcode) = @_;
   
   my $reagent = $self -> GetReagentName($barcode);
   
   if(uc($reagent) =~ /REV/) {
       return $reagent;
   }

   return 0;
}

sub GetReagentNameFwd {
    
   my ($self, $barcode) = @_;
   
   my $reagent = $self -> GetReagentName($barcode);
   
   if(uc($reagent) =~ /FWD/) {
       return $reagent;
   }

   return 0;
}


sub GetReagentName {
    
   my ($self, $barcode) = @_;
   my $dbh = $self -> {'dbh'};
   my $schema = $self->{'Schema'};
   
   my $sql = "select rn_reagent_name from reagent_informations where bs_barcode = '$barcode'";
   
   my $reagent = Query($dbh, $sql);
 
   if(defined $reagent) {
       return $reagent;
   }
   
   return 0;
   
}

sub GetFwdPrimerId {

    my ($self, $barcode) = @_;
 
    my $pri_id = $self -> GetPrimerId($barcode, 'forward');

    return $pri_id;

} #GetFwdPrimerId

sub GetRevPrimerId {

    my ($self, $barcode) = @_;
 
    my $pri_id = $self -> GetPrimerId($barcode, 'reverse');

    return $pri_id;

} #GetRevPrimerId


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


sub GetFwdDyeChemId {

    my ($self, $barcode) = @_;
 
    my $pri_id = $self -> GetDyeChemId($barcode, 'forward');

    return $pri_id;

} #GetFwdPrimerId


sub GetRevDyeChemId {

    my ($self, $barcode) = @_;
 
    my $pri_id = $self -> GetDyeChemId($barcode, 'reverse');

    return $pri_id;

} #GetRevPrimerId

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


sub GetFwdEnzId {

    my ($self, $barcode) = @_;
 
    my $pri_id = $self -> GetEnzId($barcode, 'forward');

    return $pri_id;

} #GetFwdPrimerId


sub GetRevEnzId {

    my ($self, $barcode) = @_;
 
    my $pri_id = $self -> GetEnzId($barcode, 'reverse');

    return $pri_id;

} #GetRevPrimerId


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
#    $self->{'ComparePrimerReagentToAvailVector'} = LoadSql($dbh,
#             "select vl_vl_id from ligations where lig_id =
#                 (select lig_lig_id from subclones where sub_id in
#                         (select max(sub_sub_id) from subclones_pses where pse_pse_id in
#                             (select pse_pse_id from pse_barcodes where bs_barcode = ? and direction = 'out')))", 'Single');
    $self->{'CountVlIdReagent'} = LoadSql($dbh,  "select count(*) from reagent_vector_linearizations where vl_vl_id = ? and rn_reagent_name = ?", 'Single');
#   
#    my $subclone_vl_id = $self->{'ComparePrimerReagentToAvailVector'} -> xSql($barcode);


    # the following 6 lines can probably be optimized
    my @pse_barcodes = GSC::PSEBarcode->get( direction => 'out', barcode => $barcode );
    my @dna_pse = GSC::DNAPSE->get( pse_id => $pse_barcodes[0]->pse_id );
    my $dna_id = $dna_pse[0]->dna_id;
    my $dna = GSC::DNA->get( $dna_id );
    my $vl = $dna->get_vector_linearization;
    unless ( $vl )
    {
        $self->{Error} = "$pkg: ComparePrimerReagentToAvailVector() -> Cannot get vector linearization for dna_id $dna_id";
        return 0;
    }
    my $subclone_vl_id = $vl->vl_id;

    if(defined $subclone_vl_id) {
        my $count = $self->{'CountVlIdReagent'} -> xSql($subclone_vl_id, $reagent);
        
        if($count > 0) {
            return 1;
        }
        else {
            $self->{'Error'} = "$pkg: ComparePrimerReagentToAvailVector() -> The reagent used is not valid for this type of ligation.  Reagent name '$reagent' does not match vector linearization '$subclone_vl_id'.  Barcode $barcode.  Last oracle error:" . App::DB->dbh->errstr;
        }
    }
    else {
        $self->{'Error'} = "$pkg: ComparePrimerReagentToAvailVector() -> Could not find the vl_id from the barcode = $barcode.";
    }

    return 0;
}

################################################
# Get reagent information for a Biomek machine #
################################################
sub GetReagentInfo {

    my ($self, $eq_barcode, $type) = @_;

    my $dbh=$self->{'dbh'};
    $self -> {'GetActiveResevoirReagent'} = LoadSql($dbh, "select distinct rn_reagent_name, reagent_informations.bs_barcode, pse_id from process_step_executions, pse_equipment_informations,
                                               reagent_used_pses, reagent_informations, process_steps
                                              where 
                                               pse_id = pse_equipment_informations.pse_pse_id and 
                                               ps_id = ps_ps_id and 
                                               psesta_pse_status = 'inprogress' and
                                               ps_ps_id in 
                                                           (select ps_id from process_steps where pro_process_to in 
                                                                   ('setup Biomek', 'add brew to Biomek'))  and
                                               equinf_bs_barcode in (select bs_barcode from equipment_informations where equinf_bs_barcode = ?
                                                                    and equ_equipment_description like ?) and
                                               reagent_used_pses.pse_pse_id = pse_id and
                                               RI_BS_BARCODE = bs_barcode and 
                                               upper(rn_reagent_name) like upper(?) order by pse_id desc", 'ListOfList');
    my $reagent_info = {};
    my $fwd_barcode;
    my $rev_barcode;

    my $temp = $self -> {'GetActiveResevoirReagent'} -> xSql($eq_barcode, '%FWD%',  '%FWD%');
    if(defined $temp->[0][0]) {
	$reagent_info->{'ReagentNameFwd'} = $temp->[0][0];
	$fwd_barcode = $temp->[0][1];
        $reagent_info->{'FwdDyeChemId'} = $self->GetFwdDyeChemId($fwd_barcode);
        $reagent_info->{'FwdPrimerId'} = $self->GetFwdPrimerId($fwd_barcode);
        $reagent_info->{'FwdEnzId'} = $self->GetFwdEnzId($fwd_barcode);
        $reagent_info->{'ReagentBarcodeFwd'} = $fwd_barcode;
        
        $self->{'Error'} = "$pkg:  GetReagentInfo() -> Could not find reagent information.";
        return 0 if(! defined $reagent_info->{'FwdDyeChemId'});
        return 0 if(! defined $reagent_info->{'FwdPrimerId'});
        return 0 if(! defined $reagent_info->{'FwdEnzId'});
        
        $self->{'Error'} = '';
    }
    
    if($type eq 'plasmid') {
	$temp = $self -> {'GetActiveResevoirReagent'} -> xSql($eq_barcode, '%REV%',  '%REV%');
	if(defined $temp->[0][0]) {
	    $reagent_info->{'ReagentNameRev'} = $temp->[0][0];
	    $rev_barcode = $temp->[0][1];
	
            $reagent_info->{'RevDyeChemId'} = $self->GetRevDyeChemId($rev_barcode);
            $reagent_info->{'RevPrimerId'} = $self->GetRevPrimerId($rev_barcode);
            $reagent_info->{'RevEnzId'} = $self->GetRevEnzId($rev_barcode);
            
            $self->{'Error'} = "$pkg:  GetReagentInfo() -> Could not find reagent information.";
            return 0 if(! defined $reagent_info->{'RevDyeChemId'});
            return 0 if(! defined $reagent_info->{'RevPrimerId'});
            return 0 if(! defined $reagent_info->{'RevEnzId'});
            $self->{'Error'} = '';

            $reagent_info->{'ReagentBarcodeRev'} = $rev_barcode;
        }
    }
    

    return $reagent_info;
} #GetReagentInfo

sub GetXtrackPsId {

    my ($self, $purpose, $process_step, $barcode) = @_;
    
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    my $sql = "select ps_id from process_steps where purpose = '$purpose' and  pro_process_to = '$process_step' and gro_group_name = (select distinct gro_group_name from process_steps where ps_id = 
               (select ps_ps_id from process_step_executions where psesta_pse_status = 'inprogress' and pse_id in (select pse_pse_id from 
               pse_barcodes where bs_barcode = '$barcode')))";

    my $ps_id =  Query($dbh, $sql);
    if (defined $ps_id)  {
	
        return ($ps_id);
    }
    $self->{'Error'} = "$pkg: GetXtrackPsId() -> Could not find ps_id where barcode = $barcode, process step = $process_step and purpose = $purpose.";

   return 0;
}


############################################################################################
#                                                                                          #
#                                     Insert Subrotines                                    #
#                                                                                          #
############################################################################################


#####################################
# Insert lig_id into ligations_pses #
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
# Insert an sub_id, pse_id, pl_id into the subclones_pses table #
#################################################################
#sub InsertSubclonesPses {

#    my ($self, $pse_id, $sub_id, $pl_id) = @_;

#    my $result = $self -> {'InsertSubclonesPses'} -> xSql($pse_id, $sub_id, $pl_id);

#    if($result) {
#	return $result;
#    }
    
#    $self->{'Error'} = "$pkg: InsertSubclonesPses() -> Could not insert $pse_id, $sub_id, $pl_id";
#    return 0;
#} #InsertSubclonesPses


#########################################################
# Insert an arc_id, pse_id into the archives_pses table #
#########################################################
sub InsertArchivesPses {

    my ($self, $pse_id, $arc_id) = @_;

#    my $result = $self -> {'InsertArchivesPses'} -> xSql($pse_id, $arc_id);
    my $result = GSC::ArchivePSE->create(pse_id => $pse_id, 
					 arc_id => $arc_id);

    if($result) {
	return $result;
    }
    
    $self->{'Error'} = "$pkg: InsertArchivesPses() -> Could not insert $pse_id, $arc_id";
    return 0;
} #InsertArchivesPses


####################################
# Insert Locations of Sequence DNA #
####################################
#sub InsertSeqDnaPses {

#    my ($self, $pse_id, $seqdna_id, $pl_id) = @_;

#    my $result =$self->{'InsertSeqDnaPses'}->xSql($pse_id, $seqdna_id, $pl_id);

#    if($result) {
#	return $result;
#    }
#    $self->{'Error'} = "$pkg: InsertSeqDnaPses() -> Could not insert into seq_dna_pses where pse_id = $pse_id, seqdna_id = $seqdna_id, pl_id = $pl_id.";
#    return 0;
#} #SeqDnaLocationEvent




#################################################################
# Generate a new subclones and update subclone/locations tables #
#################################################################
sub GenerateSubclonesAndLocations {

    my ($self, $pse_id, $lig_id, $arc_id, $pt_id, $sec_id) = @_;
    
    my @rows  = qw(a b c d e f g h);
    my ($i, $j);

    my $arc_obj =  GSC::Archive->get(arc_id => $arc_id);
    return 0 if(! defined $arc_obj);

    my $ArchiveNumber = $arc_obj->archive_number;
    return 0 if(!$ArchiveNumber);
    
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
	    #$result = $self -> InsertSubclonesPses($pse_id, $sub_id, $pl_id);
	    #return 0 if(!$result);
	}
    }

    return 1;
 
} #GenerateSubclonesAndLocations


sub InsertSubclones {

    my($self, $subclone, $lig_id, $sub_id, $arc_id, $pse_id, $dl_id) = @_;
    #subclone_name, lig_lig_id, sub_id, arc_arc_id
#    my $result = $self->{'InsertSubclones'}->xSql($subclone, $lig_id, $sub_id, $arc_id);
    my $result = GSC::Subclone->create(subclone_name => $subclone, 
                                       arc_id => $arc_id,
                                       dna_id => $sub_id,
                                       parent_dna_id => $lig_id,
                                       pse_id => $pse_id,
                                       dl_id => $dl_id);
    
    if($result) {
            
        return $result;
    }

    $self->{'Error'} = "$pkg: InsertSubclones() -> $subclone, $lig_id, $sub_id, $arc_id.";
}

sub InsertSequencedDnas {

    my($self, $sub_id, $primer_id, $dye_chem_id, $enz_id, $seq_id, $pse_id, $dl_id) = @_;

#    my $result = $self->{'InsertSequencedDnas'} -> xSql($sub_id, $primer_id, $dye_chem_id, $enz_id, $seq_id);

    my $result = GSC::SeqDNA->create(pri_id => $primer_id, 
					   dc_id => $dye_chem_id,
					   enz_id => $enz_id,
					   dna_id => $seq_id,
					   parent_dna_id => $sub_id,
					   pse_id => $pse_id,
					   dl_id => $dl_id);

    if($result) {

	return $result;
    }

    $self->{'Error'} = "$pkg: InsertSequencedDnas() -> $sub_id, $primer_id, $dye_chem_id, $enz_id, $seq_id.";
} #InsertSequencedDnas




##########################################################
# Log a transfer from 384 to 96 subclone locations event #
##########################################################
sub Trans384To96 {

    my ($self, $barcode, $pre_pse_id, $new_pse_id, $type, $sector) = @_;

    if(! defined $type) {
	$type = 'subclone';
    }
    
    my $lol;
    if($type eq 'archive') {
	$lol =  $self -> {'GetSubIdPlIdFromArchivePse'} -> xSql($barcode, $sector);
    }
    elsif($type eq 'subclone') {
	$lol =  $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($barcode, $pre_pse_id);
    }
    elsif($type eq 'sequenced_dna') {
	$lol =  $self -> {'GetSeqDnaIdPlIdFromSeqDnaPse'} -> xSql($barcode, $pre_pse_id);
    }
    else {
	$self -> {'Error'} = "$pkg: Trans384To96() -> Transfer type not defined.";
    }
    return 0 if(! defined $lol->[0][0]);
    
    # get sector id for a1
    my $sec_id= $self -> {'CoreSql'} -> Process('GetSectorId', 'a1');
    return ($self->GetCoreError) if(!$sec_id);
    
    # get pt_id from 96 well plate
    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', '96');
    return 0 if($pt_id == 0);
   

    foreach my $row (@{$lol}) {
	my $sub_id = $row->[0];
	my $well_384 = $row->[1];
	
	my ($well_96, $sector) = &ConvertWell::To96($well_384);

	my $pl_id = $self->GetPlId($well_96, $sec_id, $pt_id);
	return 0 if($pl_id eq '0');

	my $result = $self->{'CoreSql'} -> InsertDNAPSE($sub_id, $new_pse_id, $pl_id);
	return 0 if($result == 0);
    
	return 0 if($result == 0);
	
    }
    
    return 1;

} #Trans384To96



##########################################################
# Log a transfer from 384 to 96 subclone locations event #
##########################################################
sub Trans96To96 {

    my ($self, $barcode, $pre_pse_id, $new_pse_id, $type) = @_;

    if(! defined $type) {
	$type = 'subclone';
    }
    
    my $lol;
    if($type eq 'archive') {
	$lol =  $self -> {'GetSubIdPlIdFromArchivePse'} -> xSql($barcode, 'A1');
    }
    elsif($type eq 'subclone') {
	$lol =  $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($barcode, $pre_pse_id);
    }
    elsif($type eq 'sequenced_dna') {
	$lol =  $self -> {'GetSeqDnaIdPlIdFromSeqDnaPse'} -> xSql($barcode, $pre_pse_id);
    }
    else {
	$self -> {'Error'} = "$pkg: Trans96To96Subclone() -> Transfer type not defined.";
    }
    return 0 if(! defined $lol->[0][0]);
    
    foreach my $row (@{$lol}) {
	my $sub_id = $row->[0];
	my $well_96 = $row->[1];
	my $pl_id = $row->[2];

	my $result = $self->{'CoreSql'} -> InsertDNAPSE($sub_id, $new_pse_id, $pl_id);
	return 0 if($result == 0);
	
    }
    
    return 1;

} #Trans96To96



##########################################################
# Log a transfer from 384 to 96 subclone locations event #
##########################################################
sub Trans96To384 {

    my ($self, $barcode, $pre_pse_id, $new_pse_id, $sec_id, $type) = @_;

    if(! defined $type) {
	$type = 'subclone';
    }
    
    my $lol;
    if($type eq 'archive') {
	$lol =  $self -> {'GetSubIdPlIdFromArchivePse'} -> xSql($barcode, 'A1');
    }
    elsif($type eq 'subclone') {
	$lol =  $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($barcode, $pre_pse_id);
    }
    elsif($type eq 'sequenced_dna') {
	$lol =  $self -> {'GetSeqDnaIdPlIdFromSeqDnaPse'} -> xSql($barcode, $pre_pse_id);
    }
    else {
	$self -> {'Error'} = "$pkg: Trans96To384() -> Transfer type not defined.";
    }
    return 0 if(! defined $lol->[0][0]);
    
    # get pt_id from 96 well plate
    my $pt_id = $self -> {'CoreSql'} -> Process('GetPlateTypeId', '384');
    return 0 if($pt_id == 0);
   
    my $sector_name = $self -> GetSectorName($sec_id);
    return 0 if($sector_name eq '0');
    

    foreach my $row (@{$lol}) {
	my $sub_id = $row->[0];
	my $well_96 = $row->[1];
	
	my ($well_384) = &ConvertWell::To384($well_96, $sector_name);

	my $pl_id = $self->GetPlId($well_384, $sec_id, $pt_id);
	return 0 if($pl_id eq '0');

	my $result = $self->{'CoreSql'} -> InsertDNAPSE($sub_id, $new_pse_id, $pl_id);
	return 0 if($result == 0);
	
    }
    
    return 1;

} #Trans96To384



####################################
# Create sequence dna informations #
####################################
sub CreateSequenceDna {
    
    my ($self, $barcode, $pre_pse_id, $dye_chem_id, $primer_id, $enz_id, $pt_id, $sec_id, $new_pse_id) = @_;

    my $well_count = $self->GetWellCount($pt_id);
    return 0 if($well_count == 0);

    my $sector = $self -> GetSectorName($sec_id); 
    return 0 if($sector eq '0');
    
    my $lol =  $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($barcode, $pre_pse_id);
    if(! defined $lol->[0][0]) {
	$lol =  $self -> {'GetSubIdPlIdFromSubclonePse'} -> xSql($barcode, $pre_pse_id);
	return 0 if(! defined $lol->[0][0]);
    }

    my $source_well_count = Query($self->{'dbh'}, qq/select count(dna_id) from dna_pse dp, pse_barcodes pb 
				  where dp.pse_id = pb.pse_pse_id and pb.direction = 'out' and bs_barcode = '$barcode'/);
		   ;
    foreach my $row (@{$lol}) {
	my $sub_id = $row->[0];
	my $well_96 = $row->[1];
	my $pl_id = $row->[2];
	
	my $seq_id = $self->GetNextSeqdnaId;
	

	if(($well_count eq '384')&&($source_well_count ne '384')) {
		    
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


#################################
# Insert into reagent_used_pses #
#################################
sub InsertReagentUsedPses {

    my ($self, $barcode, $pse_id) = @_;
    my $result = $self->{'InsertReagentUsedPses'} -> xSql($barcode, $pse_id);

    #my $result = GSC::ReagentUsedPSE -> create(barcode => $barcode, 
#					       pse_id => $pse_id);
    
    
    if($result) {
	return $result;
    }
	
    $self->{'Error'} = "$pkg: InsertReagentUsedPses() -> Could not insert into reagent_used_pses.";
    return 0;
} #InsertReagentUsedPses

 

############################################################################################
#                                                                                          #
#                                     Update Subrotines                                    #
#                                                                                          #
############################################################################################

#######################
# Upate Archive Group #
#######################
sub UpdateArchiveGroup {

    my ($self, $group, $arc_id) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};

#    my $sql = "update archives set gro_group_name = '$group' where arc_id = '$arc_id'";
#    my $result = Insert($dbh, $sql);

    my $result = GSC::Archive->get($arc_id)->set(group_name => $group);
    
    if(!$result) {

	$self->{'Error'} = "$pkg: UpdateArchiveGroup() -> Could not update archives where group = $group, arc_id = $arc_id.";

	return 0;
    }

    return 1;
} #UpdateArchiveGroup

#######################
# Upate Archive Purpose #
#######################
sub UpdateArchivePurpose {

    my ($self, $arc_id, $purpose) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};

    my $sql = "update archives set ap_purpose = '$purpose' where arc_id = '$arc_id'";
    my $result = Insert($dbh, $sql);
    
    if(!$result) {

	$self->{'Error'} = "$pkg: UpdateArchivePurpose() -> Could not update archives where purpose = $purpose, arc_id = $arc_id.";

	return 0;
    }

    return 1;
} #UpdateArchivePurpose


sub UpdatePseMachine {

    my ($self, $plate_barcode, $machine_barcode) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};

    my $sql = "update equipment_informations set EQUINF_BS_BARCODE = '$machine_barcode'
               where pse_pse_id = (select pse_pse_id from pse_barcodes where bs_barcode = '$plate_barcode'
               and direction = 'out')";
    my $result =  Insert($dbh, $sql);

    if($result) {
	return $result;
    }

    $self->{'Error'} = "$pkg: UpdatePseMachine() -> Could not update equipment_informations where plate_barcode = $plate_barcode and equipment_barcode = $machine_barcode.";
    
    return 0;
} #UpdatePseMachine


sub UpdatePseXtrakDate {

    my ($self, $pse_id, $date) = @_;
    
     my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    # date format is 5/14/01 5:28:25 PM
    my $sql = "update process_step_executions set DATE_SCHEDULED = to_date('$date', 'MM/DD/YY HH:MI:SS PM') where pse_id = '$pse_id'"; 
    my $result =  Insert($dbh, $sql);

    if($result) {
	return $result;
    }

    $self->{'Error'} = "$pkg: UpdatePseXtrakDate() -> Could not update pse date to date = $date.";
    
    return 0;
    
} #UpdatePseXtrakDate



##########################################
##########################################
sub RearrayDNA384to4_96 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i=0;

    foreach my $quad  ('a1', 'a2', 'b1', 'b2') {
        
	my ($new_pse_id) = $self->{'CoreSql'} -> xOneToManyProcess($ps_id, $pre_pse_ids->[0], $update_status, $update_result, $bars_in->[0], [$bars_out->[$i]], $emp_id);
        
        my $dna_pse = App::DB->dbh->selectrow_arrayref(qw/select distinct dna_id, location_name 
                                                       from
                                                       pse_barcodes pb
                                                       join dna_pse dp on dp.pse_id = pb.pse_pse_id
                                                       join dna_location dl on dl.dl_id = dp.dl_id
                                                       where
                                                       pb.bs_barcode = '$bars_in->[0]'
                                                       and s.sector_name = '$quad'/);
        foreach my $row (@$dna_pse) {
            
            my $dna_id = $row->[0];
            my $well_384 = $row->[1];
            
            my ($well_96, $sector) = &ConvertWell::To96($well_384);
            
            my $dl = GSC::DNALocation->get(location_type => '96 well plate',
                                           location_name => $well_96,
                                           sec_id => 1);
            return unless($dl);
            
            return unless(GSC::DNAPSE->create(dna_id => $dna_id,
                                              dl_id => $dl,
                                              pse_id => $new_pse_id));
            
            
        }
        
        $i++;
        push(@$pse_ids, $new_pse_id);
    }
    
    
    
    return $pse_ids;

} #Inoculate384to96


1;

# $Header$
