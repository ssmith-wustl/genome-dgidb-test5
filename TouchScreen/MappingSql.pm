# -*-Perl-*-

##############################################
# Copyright (C) 2002 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

package TouchScreen::MappingSql;

use strict;
use ConvertWell ':all';
use DBD::Oracle;
use DBD::Oracle qw(:ora_types);
use Date::Calc qw(:all);
use DBI;
use DbAss;
use TouchScreen::CoreSql;
use Data::Dumper;
use TouchScreen::LibSql;

#############################################################
# Production sql code package
#############################################################

require Exporter;


our @ISA = qw (Exporter TouchScreen::CoreSql AutoLoader );
our @EXPORT = qw ( );

my $pkg = __PACKAGE__;

#########################################################
# Create a new instance of the MappingSql code so that you #
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
    $self->{'no_grow_cutoff'} = 50;

    $self = $class->SUPER::new( $dbh, $schema);
   
    $self->{'UpdateDNAPseLocation'} = LoadSql($dbh,"update DNA_PSE set DL_ID = ? where
               dna_id = ?  and pse_id = ?");
	       
    $self->{'GetBarcodeDesc'} = LoadSql($dbh,"select barcode_description from barcode_sources where barcode = ?", 'Single');
    $self->{'GetBarcodeClonePlWellPse'} = LoadSql($dbh, qq/select distinct clo_id, dl.dl_id, location_name 
						    from process_steps, pse_barcodes pb, clones cl, dna_pse sp, process_step_executions pse,
						    dna_location dl 
						    where 
						    cl.clo_id = sp.dna_id
						    and
						    ps_ps_id = ps_id and 
						    pb.pse_pse_id = pse.pse_id and sp.pse_id = pse.pse_id and direction = ? and dl.dl_id = sp.dl_id and 
						    bs_barcode = ?  and psesta_pse_status = ? and (pr_pse_result = 'successful' or pr_pse_result is NULL) and
						    pro_process_to = ?  order by dl.dl_id/, 'ListOfList');
    $self->{'GetBarcodeCloneGrowthPlWellPse'} = LoadSql($dbh, qq/select distinct dna_id, dl.dl_id, location_name 
						    from process_steps, pse_barcodes pb, clone_growths cl, dna_pse sp, process_step_executions pse,
						    dna_location dl 
						    where 
						    cl.cg_id = sp.dna_id
						    and
						    ps_ps_id = ps_id and 
						    pb.pse_pse_id = pse.pse_id and sp.pse_id = pse.pse_id and direction = ? and dl.dl_id = sp.dl_id and 
						    bs_barcode = ?  and psesta_pse_status = ? and (pr_pse_result = 'successful' or pr_pse_result is NULL) and
						    pro_process_to = ?  order by dl.dl_id/, 'ListOfList');

    $self -> {'GetAvailClonePf'} = LoadSql($dbh,  "select distinct pse.pse_id from 
               pse_barcodes barx, 
               process_step_executions pse,
	       dna_pse cx,
	       clone_growths cg
               where 
		   cg.cg_id = cx.dna_id and
                   barx.pse_pse_id = pse.pse_id and
                   pse.pse_id = cx.pse_id and 
                   pse.psesta_pse_status = ? and 
               barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
               (select ps_id from process_steps where pro_process_to in
               (select pro_process from process_steps where ps_id = ?) and      
                purpose = ?)", 'List');
    $self -> {'EquipmentBarcodeDescription'} = LoadSql($dbh,  qq/select 
                                               ei.equ_equipment_description || ' ' || nvl(ei.unit_name, ei.machine_number) 
					     from 
					       equipment_informations ei, BARCODE_SOURCES bs 
					     where 
					       ei.bs_barcode = bs.barcode 
					     and 
					       bs.BARCODE = ?/, 'Single');
    $self -> {'GetAvailClone'} = LoadSql($dbh,  qq/select distinct clone_name, clopre_clone_prefix, pse.pse_id from 
					     pse_barcodes barx, 
					     process_step_executions pse,
					     clones_pses cx,
					     clones
					     where 
					     clo_clo_id = clo_id and
					     barx.pse_pse_id = pse.pse_id and
					     pse.pse_id = cx.pse_pse_id and 
					     pse.psesta_pse_status = ? and 
					     barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
					     (select ps_id from process_steps where pro_process_to in
					      (select ps1.pro_process from process_steps ps, process_steps ps1 where ps.pro_process_to = ps1.pro_process_to and ps.ps_id = ?))/, 'ListOfList');
    $self -> {'GetAvailPseOnMachine'} = LoadSql($dbh,  qq/ select distinct dp.pse_id from dna d, dna_pse dp, equipment_informations ei, pse_equipment_informations pei, process_step_executions pse
		where d.dna_id = dp.dna_id
		and dp.pse_id = pei.pse_pse_id and pse.pse_id = dp.pse_id and pse.psesta_pse_status = 'inprogress'   
 		and pei.equinf_bs_barcode = ei.bs_barcode and ei.bs_barcode = ?/, 'single');   
    $self -> {'GetAvailCloneGrowth_20031231'} = LoadSql($dbh,  qq/select distinct substr(c.clone_name, 0, length(c.clone_name) - 3) || ' ' || s.sector_name, clopre_clone_prefix, pse.pse_id from 
					     pse_barcodes barx, 
					     process_step_executions pse,
					     dna_pse cx,
					     clone_growths cg,
					     clones c,dna_pse dpi, dna_location dl, sectors s
					     where 
					     s.sec_id = dl.sec_id and
					     dpi.dl_id = dl.dl_id and
					     dpi.dna_id = c.clo_id and
					     c.clo_id = cg.clo_clo_id and
					     cg.cg_id = cx.dna_id and
					     barx.pse_pse_id = pse.pse_id and
					     pse.pse_id = cx.pse_id and 
					     pse.psesta_pse_status = ? and 
					     barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
					     (select ps_id from process_steps where pro_process_to in
					      (select pro_process from process_steps where ps_id = ?))/, 'ListOfList');
    $self -> {'GetAvailCloneGrowth'} = LoadSql($dbh,  qq/select distinct substr(c.clone_name, 0, length(c.clone_name) - 3) || ' ' || s.sector_name, clopre_clone_prefix, pse.pse_id from 
					     pse_barcodes barx, 
					     process_step_executions pse,
					     dna_pse cx,
					     clone_growths cg,
					     clones c,dna_pse dpi, dna_location dl, sectors s
					     where 
					     s.sec_id = dl.sec_id and
					     dpi.dl_id = dl.dl_id and
					     dpi.dna_id = c.clo_id and
					     c.clo_id = cg.clo_clo_id and
					     cg.cg_id = cx.dna_id and
					     barx.pse_pse_id = pse.pse_id and
					     pse.pse_id = cx.pse_id and 
					     pse.psesta_pse_status = ? and 
					     barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
					     (select ps_id from process_steps where pro_process_to in
					      (select ps1.pro_process from process_steps ps, process_steps ps1 where ps.pro_process_to = ps1.pro_process_to and ps.ps_id = ?))/, 'ListOfList');
    $self -> {'GetAvailCloneGrowth_old'} = LoadSql($dbh,  qq/select distinct clone_name, clopre_clone_prefix, pse.pse_id from 
					     pse_barcodes barx, 
					     process_step_executions pse,
					     dna_pse cx,
					     clone_growths cg,
					     clones c
					     where 
					     c.clo_id = cg.clo_clo_id and
					     cg.cg_id = cx.dna_id and
					     barx.pse_pse_id = pse.pse_id and
					     pse.pse_id = cx.pse_id and 
					     pse.psesta_pse_status = ? and 
					     barx.bs_barcode = ? and barx.direction = ? and pse.ps_ps_id in 
					     (select ps_id from process_steps where pro_process_to in
					      (select pro_process from process_steps where ps_id = ?))/, 'ListOfList');
    
    $self -> {'GetAvailGlycerolPlate'} = LoadSql($dbh,  qq/select distinct c.clone_name, c.clopre_clone_prefix, pse.pse_id from 
					     dna_pse dp, clones c, dna d ,(
					     select * from process_step_executions pse 
					     where pse.psesta_pse_status = ?
					       and ps_ps_id in (select ps_id from process_steps where pro_process_to in
                                        						   (select pro_process from process_steps where ps_id = ?))
					     start with pse_id in (
					     select pse_id from process_step_executions pse
					     where prior_pse_id is null or prior_pse_id = 1
					     start with pse.pse_id = (select pb.pse_pse_id from pse_barcodes pb where pb.bs_barcode = ? and pb.direction = ?)
					     connect by pse.pse_id = prior pse.prior_pse_id  )
					     connect by prior pse.pse_id = pse.prior_pse_id) pse
					     where
					       d.dna_id = dp.dna_id and
					       c.clo_id = dp.dna_id and
					       dp.pse_id = pse.pse_id/, 'ListOfList'); 
 
    $self -> {'GetAvailCloneCyclePlate_old'} = LoadSql($dbh,  qq/select distinct clone_name, clopre_clone_prefix, pse.pse_id from 
					     pse_barcodes barx, 
					     process_step_executions pse,
					     dna_pse cx,
					     clone_growths cg,
					     clones c
					     where 
					     cg.cg_id = cx.dna_id and
					     cg.clo_clo_id = c.clo_id and
					     barx.pse_pse_id = pse.pse_id and
					     pse.pse_id = cx.pse_id and 
					     pse.psesta_pse_status = 'inprogress' and 
					     barx.bs_barcode = ? and barx.direction = 'in'
					     and pse.ps_ps_id in 
					     (select ps_id from process_steps where pro_process_to = 'add loading dye to cycle plate' or pro_process_to = 'reload digest gel')/, 'ListOfList');
    
    $self -> {'GetAvailCloneCyclePlate'} = LoadSql($dbh,  qq/select distinct substr(c.clone_name, 0, length(c.clone_name) - 3) || ' ' || s.sector_name, clopre_clone_prefix, pse.pse_id from
					     pse_barcodes barx, 
					     process_step_executions pse,
					     dna_pse cx,
					     clone_growths cg,
					     clones c,dna_pse dpi, dna_location dl, sectors s
					     where
					     s.sec_id = dl.sec_id and
					     dpi.dl_id = dl.dl_id and
					     dpi.dna_id = c.clo_id and 
					     cg.cg_id = cx.dna_id and
					     cg.clo_clo_id = c.clo_id and
					     barx.pse_pse_id = pse.pse_id and
					     pse.pse_id = cx.pse_id and 
					     pse.psesta_pse_status = 'inprogress' and 
					     barx.bs_barcode = ? and barx.direction = 'in'
					     and pse.ps_ps_id in 
					     (select ps_id from process_steps where pro_process_to = 'add loading dye to cycle plate' or pro_process_to = 'reload digest gel')/, 'ListOfList');
    $self -> {'GetAvailCloneCyclePlateForReload'} = LoadSql($dbh,  qq/select distinct substr(c.clone_name, 0, length(c.clone_name) - 3) || ' ' || s.sector_name, clopre_clone_prefix, pse.pse_id from
					     pse_barcodes barx, 
					     process_step_executions pse,
					     dna_pse cx,
					     clone_growths cg,
					     clones c,dna_pse dpi, dna_location dl, sectors s
					     where
					     s.sec_id = dl.sec_id and
					     dpi.dl_id = dl.dl_id and
					     dpi.dna_id = c.clo_id and 
					     cg.cg_id = cx.dna_id and
					     cg.clo_clo_id = c.clo_id and
					     barx.pse_pse_id = pse.pse_id and
					     pse.pse_id = cx.pse_id and 
					     pse.psesta_pse_status = 'completed' and 
					     barx.bs_barcode = ? and barx.direction = 'in'
					     and pse.ps_ps_id in 
					     (select ps_id from process_steps where pro_process_to = 'add loading dye to cycle plate')/, 'ListOfList');
    $self -> {'GetAvailCloneCyclePlateForReload_old'} = LoadSql($dbh,  qq/select distinct clone_name, clopre_clone_prefix, pse.pse_id from 
					     pse_barcodes barx, 
					     process_step_executions pse,
					     dna_pse cx,
					     clone_growths cg,
					     clones c
					     where 
					     cg.cg_id = cx.dna_id and
					     cg.clo_clo_id = c.clo_id and
					     barx.pse_pse_id = pse.pse_id and
					     pse.pse_id = cx.pse_id and 
					     pse.psesta_pse_status = 'completed' and 
					     barx.bs_barcode = ? and barx.direction = 'in'
					     and pse.ps_ps_id in 
					     (select ps_id from process_steps where pro_process_to = 'add loading dye to cycle plate')/, 'ListOfList');
    
    
    
    $self -> {'GetCloPlIdFromClonePse_old'} = LoadSql($dbh, qq/select distinct clo_clo_id, well_name, pl_id  
							   from pse_barcodes pbx, clones_pses cx, plate_locations pl
							   where pbx.bs_barcode = ? and pbx.direction = 'out' and 
							   pl.pl_id = cx.pl_pl_id and 
							   pbx.pse_pse_id = cx.pse_pse_id and 
							   cx.clo_clo_id in  (select distinct clo_clo_id from clones_pses where 
									       pse_pse_id = ?)/, 'ListOfList');
    
    $self -> {'GetCloPlIdFromClonePse'} = LoadSql($dbh, qq/select distinct dna_id, location_name, pl.dl_id  
							   from pse_barcodes pbx, dna_pse cx, dna_location pl
							   where pbx.bs_barcode = ? and pbx.direction = 'out' and 
							   pl.dl_id = cx.dl_id and 
							   pbx.pse_pse_id = cx.pse_id and 
							   cx.dna_id in  (select distinct dna_id from dna_pse where 
									       pse_id = ?)/, 'ListOfList');
    
    $self -> {'GetCloLaneFromClonePse_old'} = LoadSql($dbh, qq/select distinct clo_clo_id, gel_lanes
						      from pse_barcodes pbx, clones_pses cx
						      where pbx.bs_barcode = ? and pbx.direction = 'out' and 
						      pbx.pse_pse_id = cx.pse_pse_id and 
						      cx.clo_clo_id in  (select distinct clo_clo_id from clones_pses where 
									      pse_pse_id = ?)/, 'ListOfList');
    
    $self -> {'GetCloneFromEquipment'} = LoadSql($dbh, qq{select /*+ use_nl(pb pse) index(pse pse_pk) index(pei pei_pk) */
                                                            pb.bs_barcode 
                                                          from 
							    pse_equipment_informations pei, pse_barcodes pb, process_step_executions pse 
							  where
							    pb.pse_pse_id = pse.pse_id
							  and
							    pei.pse_pse_id = pse.pse_id 
							  and 
							     pse.psesta_pse_status = 'inprogress'
							  and
							    equinf_bs_barcode = ?}, 'ListOfList');
    
    $self -> {'GetCloLaneFromClonePse'} = LoadSql($dbh, qq/select distinct dna_id, dl_id
						      from pse_barcodes pbx, dna_pse cx
						      where pbx.bs_barcode = ? and pbx.direction = 'out' and 
						      pbx.pse_pse_id = cx.pse_id and 
						      cx.dna_id in  (select distinct dna_id from dna_pse where 
									      pse_id = ?)/, 'ListOfList');
    
    $self -> {'GetCloPlIdFromClonePseSector'} = LoadSql($dbh, qq/select distinct clo_clo_id, well_name, pl_id  
							    from pse_barcodes pbx, clones_pses cx, plate_locations pl, sectors
							    where pbx.bs_barcode = ? and pbx.direction = 'out' and 
							    sec_id = sec_sec_id and
							    sector_name = ? and
							    pl.pl_id = cx.pl_pl_id and 
							    pbx.pse_pse_id = cx.pse_pse_id and 
							    cx.clo_clo_id in  (select distinct clo_clo_id from clones_pses where 
									       pse_pse_id = ?)/, 'ListOfList');

    $self->{'GetAvailableQuadsPses'} = LoadSql($dbh, qq/select distinct UPPER(sector_name), cx.pse_pse_id from sectors,
						   plate_locations, clones_pses cx, plate_types, process_step_executions pse
						   where 
						   pse.pse_id = cx.pse_pse_id and pse.psesta_pse_status = 'scheduled' and
						   cx.pse_pse_id in (select pse_pse_id from pse_barcodes where bs_barcode = ? and
								     direction = 'out')  and 
						   pl_pl_id = pl_id and 
						   sec_sec_id = sec_id and 
						   pt_pt_id = pt_id and 
						   well_count = '384' order by UPPER(sector_name)/, 'ListOfList');


    $self->{'GetAvailableQuadsPsesIn'} = LoadSql($dbh, qq/select distinct sector_name, cx.pse_pse_id from sectors,
						   plate_locations, clones_pses cx, plate_types, process_step_executions pse, process_steps ps
						   where 
						   --filter on purpose to mask library construction steps, which stay inprogress
						   ps.ps_id = pse.ps_ps_id and ps.purpose not in ('Library Request') and
						   pse.pse_id = cx.pse_pse_id and pse.psesta_pse_status = 'inprogress' and
						   cx.pse_pse_id in (select pse_pse_id from pse_barcodes where bs_barcode = ? and
								     direction = 'in')  and 
						   pl_pl_id = pl_id and 
						   sec_sec_id = sec_id and 
						   pt_pt_id = pt_id and 
						   well_count = ? order by sector_name/, 'ListOfList');


 $self->{'GetAvailableEzymesPses'} = LoadSql($dbh, qq/select e.enzyme_name, ep.pse_pse_id from enzymes e, enzymes_pses ep, process_step_executions pse where pse.pse_id = ep.pse_pse_id and e.enz_id = ep.enz_enz_id and pse.psesta_pse_status = 'scheduled' and ep.pse_pse_id in (
select pse.pse_id from process_step_executions pse where pse.ps_ps_id in (select ps_id from process_steps where pro_process_to = 'digest setup') start with pse.pse_id in (
select pse.pse_id from process_step_executions pse where (pse.prior_pse_id = 1 or pse.prior_pse_id is null) start with pse.pse_id in (
select pse_pse_id from pse_barcodes where bs_barcode = ? and
       direction = 'out') connect by pse.pse_id = prior pse.prior_pse_id
) connect by prior pse.pse_id = pse.prior_pse_id)/, 'ListOfList');

    $self->{'CountUseGel'} = LoadSql($dbh, qq/select count(*) from pse_equipment_informations pb, process_step_executions pse, process_steps ps where
	pb.pse_pse_id = pse.pse_id and
	pse.ps_ps_id = ps.ps_id and
	ps.pro_process = 'pour gel' and
	pse.psesta_pse_status = 'inprogress' and
                               pb.equinf_bs_barcode = ?/, 'Single');

    $self->{'GetBarcodeEquipmentPSES'} = LoadSql($dbh, qq/select distinct pse.pse_id 
        from pse_equipment_informations pb, process_step_executions pse
	where
	pb.pse_pse_id = pse.pse_id and
	pse.psesta_pse_status = ? and
        pb.equinf_bs_barcode = ?/, 'ListOfList');
    $self->{'GetBarcodeDNAPSES'} = LoadSql($dbh, qq/select distinct pse.pse_id 
        from pse_barcodes pb, process_step_executions pse
	where
	pb.pse_pse_id = pse.pse_id and
	pse.psesta_pse_status = ? and
        pb.bs_barcode = ?/, 'ListOfList');

    $self->{'GetPlId'} = LoadSql($dbh, "select pl_id from plate_locations where well_name = ? and 
                                    sec_sec_id = ? and pt_pt_id = ?", 'Single');

    $self->{'GetDlId'} = LoadSql($dbh, "select dl_id from dna_location where location_name = ? and 
                                    location_type = ?", 'Single');

#    $self->{'InsertClonesPsesWell'} = LoadSql($dbh,"insert into clones_pses (clo_clo_id, pse_pse_id, pl_pl_id) values (?, ?, ?)");
#    $self->{'InsertClonesPsesLane'} = LoadSql($dbh,"insert into clones_pses (clo_clo_id, pse_pse_id, gel_lanes) values (?, ?, ?)");
#    $self->{'UpdateClonesPsesWell'} = LoadSql($dbh,"update clones_pses set pl_pl_id = ? where clo_clo_id = ? and pse_pse_id = ?");
    $self->{'EditPlateToEquipment'} = LoadSql($dbh,qq/
     DECLARE
       vBS_BARCODE EQUIPMENT_INFORMATIONS.BS_BARCODE%TYPE;
       vPSE_ID PROCESS_STEP_EXECUTIONS.PSE_ID%TYPE;
       vEIS_EQUIPMENT_STATUS EQUIPMENT_INFORMATIONS.EIS_EQUIPMENT_STATUS%TYPE;
     BEGIN
       vBS_BARCODE := ?;
       vPSE_ID := ?;
       vEIS_EQUIPMENT_STATUS := ?;
       insert into pse_equipment_informations (EQUINF_BS_BARCODE, PSE_PSE_ID) values (vBS_BARCODE, vPSE_ID);
       update equipment_informations set EIS_EQUIPMENT_STATUS = vEIS_EQUIPMENT_STATUS where BS_BARCODE = vBS_BARCODE;
     END;/);
    $self -> {'GetEnzIdFromReagent_old'} = LoadSql($dbh, qq/select distinct enz_enz_id from enzymes_reagent_names where rn_reagent_name =
						   (select distinct rn_reagent_name from reagent_informations where bs_barcode = ?)/, 'Single');
    $self -> {'GetEnzIdFromReagent'} = LoadSql($dbh, qq/select distinct enz_enz_id from enzymes_reagent_names where rn_reagent_name =
						   (select distinct rn_reagent_name from reagent_informations where bs_barcode = ?)/, 'ListOfList');
    $self -> {'GetEnzPseFromProcessBarcode_old'} = LoadSql($dbh, qq/select distinct enz_id, pse_id, enzyme_name
							   from enzymes_pses ep, enzymes, process_step_executions, clones_pses cp where 
							   enz_enz_id = enz_id and
							   ep.pse_pse_id  = pse_id and							   
							   cp.pse_pse_id = pse_id and 
							   ps_ps_id = ? and
							   clo_clo_id in (select max(clo_clo_id) from clones_pses cp, pse_barcodes pb where 
									  cp.pse_pse_id = pb.pse_pse_id and
									  bs_barcode = ? and
									  direction = 'out')/, 'ListOfList');
    $self -> {'GetEnzPseFromProcessBarcode'} = LoadSql($dbh, qq/select distinct enz_id, pse.pse_id, enzyme_name
							   from enzymes_pses ep, enzymes, process_step_executions pse, dna_pse cp where 
							   enz_enz_id = enz_id and
							   ep.pse_pse_id  = pse.pse_id and							   
							   cp.pse_id = pse.pse_id and 
							   ps_ps_id = ? and
							   dna_id in (select max(clo_clo_id) from dna_pse cp, pse_barcodes pb, clone_growths cg where 
							    		  cp.dna_id = cg.cg_id and
									  cp.pse_id = pb.pse_pse_id and
									  bs_barcode = ? and
									  direction = 'out')/, 'ListOfList');
    $self -> {'GetScheduledEnzPseFromProcessBarcode'} = LoadSql($dbh, qq/select distinct enz_id, pse.pse_id, enzyme_name
							   from enzymes_pses ep, enzymes, process_step_executions pse, dna_pse cp where 
							   enz_enz_id = enz_id and
							   ep.pse_pse_id  = pse.pse_id and							   
							   cp.pse_id = pse.pse_id and pse.psesta_pse_status in ('inprogress', 'scheduled') and
							   ps_ps_id = ? and
							   dna_id in (select max(clo_clo_id) from dna_pse cp, pse_barcodes pb, clone_growths cg where 
							    		  cp.dna_id = cg.cg_id and
									  cp.pse_id = pb.pse_pse_id and
									  bs_barcode = ? and
									  direction = 'out')/, 'ListOfList');
    $self -> {'IsThisNextAvailableSlot_old'} = LoadSql($dbh, qq/select 
								bs_barcode, unit_name
							    from
							       equipment_informations
							    where
							      EIS_EQUIPMENT_STATUS = 'vacant'
							    and
							      equinf_bs_barcode in (
							    select
							      equinf_bs_barcode
							    from
							      equipment_informations
							    where
							      bs_barcode = ?
							    )/, 'ListOfList');

    $self -> {'IsThisNextAvailableSlot'} = LoadSql($dbh, qq/select 
								distinct ei.bs_barcode, ei.unit_name
							    from
							       equipment_informations ei,
							       pse_equipment_informations pei,
							       process_step_executions pse
							    where
							       ei.bs_barcode = pei.equinf_bs_barcode
							     and 
							       pei.pse_pse_id = pse.pse_id
							     and
							     	pse.psesta_pse_status = 'inprogress'
							     and
							      ei.equinf_bs_barcode in (
							    select
							      equinf_bs_barcode
							    from
							      equipment_informations
							    where
							      bs_barcode = ?
							    )/, 'ListOfList');

    $self -> {'GetEquipmentSlot_old'} = LoadSql($dbh, qq/select 
								bs_barcode, unit_name, equ_equipment_description
							    from
							       equipment_informations
							    where
							      equinf_bs_barcode in (
							    select
							      bs_barcode
							    from
							      equipment_informations
							    where
							      equinf_bs_barcode = ?
							    ) and equ_equipment_description = ? and 							      
							    EIS_EQUIPMENT_STATUS = ?/, 'ListOfList');
    $self -> {'GetEquipmentSlot_ORI'} = LoadSql($dbh, qq{select
								bs_barcode, unit_name, equ_equipment_description
							    from
							       equipment_informations
							    where
							      equinf_bs_barcode in (
							    select
							      bs_barcode
							    from
							      equipment_informations
							    where
							      equinf_bs_barcode = ?
							    ) and equ_equipment_description = ? and 							      
							    bs_barcode not in (select 
								distinct pei.equinf_bs_barcode
							    from
							       pse_equipment_informations pei,
							       process_step_executions pse
							    where
							       pse.pse_id = pei.pse_pse_id
							     and
							     	pse.psesta_pse_status = 'inprogress')}, 'ListOfList');
    $self -> {'GetEquipmentSlot'} = LoadSql($dbh, qq{select
								distinct i.bs_barcode, i.unit_name, i.equ_equipment_description
							    from
							       equipment_informations i,
							       equipment_informations ii
							    where
							      i.equinf_bs_barcode = ii.bs_barcode
							    and
							      ii.equinf_bs_barcode = ?
							    and i.equ_equipment_description = ?
							    MINUS
							    select /*+ RULE */
								distinct ei.bs_barcode, ei.unit_name, ei.equ_equipment_description
							    from
							       pse_equipment_informations pei,
							       process_step_executions pse,
							       equipment_informations ei,
							       equipment_informations eii
							    where
							        pei.pse_pse_id = pse.pse_id (+)
							     and
							        ei.bs_barcode = pei.equinf_bs_barcode (+)
							     and
							     	pse.psesta_pse_status = 'inprogress'
							     and
							        eii.bs_barcode = ei.equinf_bs_barcode
							     and
							        eii.equinf_bs_barcode = ?
							     and 
							        ei.equ_equipment_description = ?}, 'ListOfList');
								
    $self -> {'GetEquipmentSlot_wrong'} = LoadSql($dbh, qq{select /*+ RULE */
								distinct ei.bs_barcode, ei.unit_name, ei.equ_equipment_description
							    from
							       pse_equipment_informations pei,
							       process_step_executions pse,
							       equipment_informations ei,
							       equipment_informations eii
							    where
							        pei.pse_pse_id = pse.pse_id (+)
							     and
							        ei.bs_barcode = pei.equinf_bs_barcode (+)
							     and
							     	(pse.psesta_pse_status != 'inprogress' or pse.psesta_pse_status is null)
							     and
							      eii.bs_barcode = ei.equinf_bs_barcode
							     and
							      eii.equinf_bs_barcode = ?
							     and 
							        ei.equ_equipment_description = ?}, 'ListOfList');
								
    $self -> {'GetAvailMachineInInprogress'} = LoadSql($dbh, qq/select 
								equ_equipment_description || ' ' || unit_name, bs_barcode, unit_name
							    from
							       equipment_informations
							    where
							    --  EIS_EQUIPMENT_STATUS = 'vacant'
							    --and
							      equinf_bs_barcode is null
							    and
							      bs_barcode = ?
							    /, 'ListOfList');

    $self -> {'GetAvailEquipmentSlotInInprogress_slow'} = LoadSql($dbh, qq/select 
							       bs_barcode, unit_name, equ_equipment_description
							    from
							       equipment_informations
							    where
							      equinf_bs_barcode in (
							    select
							      bs_barcode
							    from
							      equipment_informations
							    where
							      equinf_bs_barcode = ?
							    ) and equ_equipment_description = 'Culture Slot' and 							      
							    bs_barcode in (select 
								distinct pei.equinf_bs_barcode
							    from
							       pse_equipment_informations pei,
							       process_step_executions pse
							    where
							       pse.pse_id = pei.pse_pse_id
							     and
							     	pse.psesta_pse_status = 'inprogress')/, 'ListOfList');

    $self -> {'GetAvailEquipmentSlotInInprogress'} = LoadSql($dbh, qq{select /*+ RULE */
								distinct ei.bs_barcode, ei.unit_name, ei.equ_equipment_description
							    from
							       pse_equipment_informations pei,
							       process_step_executions pse,
							       equipment_informations ei,
							       equipment_informations eii
							    where
							        pei.pse_pse_id = pse.pse_id (+)
							     and
							        ei.bs_barcode = pei.equinf_bs_barcode (+)
							     and
							     	pse.psesta_pse_status = 'inprogress'
							     and
							        eii.bs_barcode = ei.equinf_bs_barcode
							     and
							        eii.equinf_bs_barcode = ?
							     and 
							        ei.equ_equipment_description = 'Culture Slot'}, 'ListOfList');

    $self->{'CheckIfAvailableForSetup'} = LoadSql($dbh, qq/select count(*) from process_step_executions, pse_equipment_informations, process_steps
						      where 
						      pse_id = pse_pse_id and 
						      ps_id = ps_ps_id  and
						      pro_process_to = 'digest gel staining' and
						      psesta_pse_status = 'inprogress' and
						      equinf_bs_barcode = ?/, 'Single');
    
    $self->{'CheckIfAvailableScanPlateForSetup'} = LoadSql($dbh, qq/select count(*) from process_step_executions, pse_equipment_informations, process_steps
						      where 
						      pse_id = pse_pse_id and 
						      ps_id = ps_ps_id  and
						      pro_process_to = 'digest gel to scan plate' and
						      psesta_pse_status = 'inprogress' and
						      equinf_bs_barcode = ?/, 'Single');
    
    $self->{'GetStainGelBarcodePse'} = LoadSql($dbh, qq/select pb.bs_barcode, pse_id  from process_step_executions, pse_equipment_informations pe, process_steps,
						   pse_barcodes pb
						   where 
						   pse_id = pe.pse_pse_id and 
						   pse_id = pb.pse_pse_id and 
						   ps_id = ps_ps_id  and
						   pro_process_to = 'digest gel staining' and
						   psesta_pse_status = 'inprogress' and
						   equinf_bs_barcode = ?/, 'ListOfList');

    $self->{'GetEquipmentSlotPlateBarcodePse'} = LoadSql($dbh, qq/select pb.bs_barcode, pse_id  from process_step_executions, pse_equipment_informations pe, process_steps,
						   pse_barcodes pb
						   where 
						   pse_id = pe.pse_pse_id and 
						   pse_id = pb.pse_pse_id and 
						   ps_id = ps_ps_id  and
						   pro_process_to = 'brinkmann setup' and
						   psesta_pse_status = 'inprogress' and
						   direction = 'in' and
						   equinf_bs_barcode = ?/, 'ListOfList');

    $self->{'CheckIfRigAvailable'} = LoadSql($dbh, qq/select count(*) from process_step_executions, pse_barcodes where 
						 pse_id = pse_pse_id and 
						 ps_ps_id in (select ps_id from process_steps where purpose = 'Run Digest Gel' and
							      pro_process_to = 'set up gel rig') and
						 direction = 'in' and
						 psesta_pse_status = 'inprogress' and
						 bs_barcode = ?/, 'Single');
    
    $self->{'GetAvailGelPsePosition_old'} = LoadSql($dbh, qq/select distinct pse_id, data_value 
						    from process_step_executions, process_steps, pse_barcodes pb, pse_data_outputs pd, PROCESS_STEP_OUTPUTS pso
						    where 
						    ps_id = pso.ps_ps_id and 
						    pro_process_to = 'pour gel' and
						    pse_id = pb.pse_pse_id and 
						    pse_id = pd.pse_pse_id and 
						    pso_pso_id = pso_id and
						    OUTPUT_DESCRIPTION = 'Gel Position' and
						    psesta_pse_status = 'inprogress' and
						    bs_barcode = ? and
						    direction = 'out'/, 'ListOfList');
    $self->{'GetAvailGelPsePosition'} = LoadSql($dbh, qq{select /*+ RULE */ distinct pse_id, data_value 
						    from process_step_executions, process_steps, pse_equipment_informations pb, pse_data_outputs pd, PROCESS_STEP_OUTPUTS pso
						    where 
						    ps_id = pso.ps_ps_id and 
						    pro_process_to = 'pour gel' and
						    pse_id = pb.pse_pse_id and 
						    pse_id = pd.pse_pse_id and 
						    pso_pso_id = pso_id and
						    OUTPUT_DESCRIPTION = 'Gel Position' and
						    psesta_pse_status = 'inprogress' and
						    pb.equinf_bs_barcode = ?}, 'ListOfList');

   $self->{'GetAvailableStreaks'} = LoadSql($dbh, qq/select tp.pse_id, tp.barcode, dtp.barcode, d.dna_name, dl.location_name, dl.dl_id from process_step_executions pse
					     join process_steps ps on ps.ps_id = pse.ps_ps_id
					     join tpp_pse tp on tp.pse_id = pse.pse_id
					     join dna_pse dp on dp.pse_id = tp.prior_pse_id
					     join dna d on d.dna_id = dp.dna_id
					     join dna_location dl on dl.dl_id = dp.dl_id
					     join tpp_pse dtp on pse.pse_id = dtp.pse_id and dtp.container_position = 2
					     where ps.pro_process_to ='streak'
					     and pse.psesta_pse_status = 'scheduled'
					     and tp.container_position=1 and tp.barcode= ?
					     order by dl.location_order/,'ListOfList');

    $self->{'ActiveScanPosition'} = 0;
    $self -> {'DigestGelPosition'} = '';
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

##########################################
#     Output verification Subroutines    #
##########################################
sub CheckIfUsedCombAsOutput {

    my ($self, $barcode) = @_;
    #LSF: Since the fingerprinting wants to reuse the comb for 
    #     different session even though the comb tie to an inprogress pour gel,
    #     I just simply return the barcode description.
    my $bar_desc = $self->{'EquipmentBarcodeDescription'} -> xSql($barcode);
    if(! $bar_desc) {
      $bar_desc = $self->{'BarcodeDesc'} -> xSql($barcode);
    }
    if(defined $bar_desc) {
	return $bar_desc;
    }
    elsif(defined $DBI::errstr){
	$self->{'Error'} = $DBI::errstr;
    }
    else {
	$self->{'Error'} = "Could not find description information for barcode = $barcode.";
    }	
    return (0, $self->{'Error'});

} #CheckIfUsedAsOutput

sub CheckIfUsedGelAsOutput {

    my ($self, $barcode) = @_;

    my $desc = $self-> CheckIfUsedGel($barcode, 'out');
    #return ($self->GetCoreError) if(!$desc);
    return (0, $self->{'Error'}) if(!$desc);
    return $desc;

} #CheckIfUsedAsOutput

sub CheckIfUsedGelPositionAsOutput {

    my ($self, $barcode, $bm) = @_;
    my $col = $bm->GetNumberOfScans;
    my $tdesc = $self->{'EquipmentBarcodeDescription'} -> xSql($barcode);
    if($col == 1) {
      if($tdesc !~ /top$/i) {
	  $self->{'Error'} = "Barcode $barcode ($tdesc) is not top position!";
	  return 0;    
      }
    }
    if($col == 3) {
      if($tdesc !~ /bottom$/i) {
	  $self->{'Error'} = "Barcode $barcode ($tdesc) is not bottom position!";
	  return 0;    
      }
    }
    my $desc = $self-> CheckIfUsedGel($barcode, 'out');
    #return ($self->GetCoreError) if(!$desc);
    #return (0, $self->{'Error'}) if(!$desc);
    return 0 if(! $desc);
    return $desc;

} #CheckIfUsedGelPositionAsOutput

sub CheckIfUsedGel {
    my ($self, $barcode, $direction) = @_;

    if($self->{'CountUseGel'} -> xSql($barcode) == 0) {
	#LSF: Need to check for the "digest gel loading" step to make sure there is not used.
	my @pbs = GSC::PSEBarcode->load(sql => [qq/select pb.* from pse_barcodes pb, process_step_executions pse where pb.pse_pse_id = pse.pse_id and pse.psesta_pse_status = 'inprogress' and pb.bs_barcode = ? /, $barcode]);
	if(! @pbs) {
	  #my $bar_desc = $self->{'BarcodeDesc'} -> xSql($barcode);
	  my $bar_desc = $self->{'EquipmentBarcodeDescription'} -> xSql($barcode);
	  if(! $bar_desc) {
	    $bar_desc = $self->{'BarcodeDesc'} -> xSql($barcode);
	  }
	  if(defined $bar_desc) {
	      return $bar_desc;
	  }
          elsif(defined $DBI::errstr){
	      $self->{'Error'} = $DBI::errstr;
	  }
	  else {
	      $self->{'Error'} = "Could not find description information for barcode = $barcode.";
	  }
	} else {
	  $self->{'Error'} = "There are " . scalar @pbs . "[" . (join ",", map { $_->pse_id } @pbs) . "]" . " pse(s) still used the GEL with the barcode $barcode!";
	}

    }
    elsif(defined $DBI::errstr){
	$self->{'Error'} = $DBI::errstr;
    }
    else {
	$self->{'Error'} = "Could not determine count for barcode = $barcode.";
    }	

    return 0;
} #CheckIfUsed

sub CheckIfUsedAsOutput {

    my ($self, $barcode) = @_;

    my $desc = $self -> CheckIfUsed($barcode, 'out');
    return ($self->GetCoreError) if(!$desc);
    return $desc;

} #CheckIfUsedAsOutput


sub CheckIfUsedAsCarouselSlotOutput {

    my ($self, $barcode) = @_;
    my $desc;
    print "MACHINE => " , Dumper($self);
    if($self->isThisNextAvailableSlot($barcode)) {
      $desc = $self -> CheckIfUsed($barcode, 'out');
    }

    return ($self->GetCoreError) if(!$desc);
    return $desc;
    
} #CheckIfUsedAsOutput


sub GetAvailDigestStainTray {

    my ($self, $barcode, $ps_id) = @_;


    my $used = $self->{'CheckIfAvailableForSetup'} -> xSql($barcode);

    if($used) {
	my $desc = $self->{'BarcodeDesc'}-> xSql($barcode);
	return $desc;
    }
    
    $self->{'Error'} = "$pkg: CheckIfRigAvailable -> Tray is not available.";
    return 0;

}

sub GetAvailCloneOutInprogressInDigestStainTray {

    my ($self, $barcode, $ps_id) = @_;


    my $used = $self->{'CheckIfAvailableForSetup'} -> xSql($barcode);

    if($used) {
        my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});
	my $lol = $TouchSql->{'GetEquipmentContain'}-> xSql($barcode);
	if($lol->[0][0]) {
	  return ($lol->[0][1] . " " . $lol->[0][2], [$lol->[0][0]]);
	}
    }
    
    $self->{'Error'} = "$pkg: CheckIfRigAvailable -> Tray is not available.";
    return 0;

}


sub CheckIfTrayAvailable {

    my ($self, $barcode, $ps_id) = @_;

    if($barcode =~ /^0j/) {
      my $used = $self->{'CheckIfAvailableForSetup'} -> xSql($barcode);

      if(!$used) {
	  my $desc = $self->{'BarcodeDesc'}-> xSql($barcode);
	  if($desc =~ /Stain Tray/i) {
	    return $desc;
          } else {
	    $self->{'Error'} = "$pkg: CheckIfTrayAvailable -> $barcode [$desc] is not a Stain Tray.";
	    return 0;
	  }
      }
      $self->{'Error'} = "$pkg: CheckIfTrayAvailable -> Tray is not available.";
    } else {
      $self->{'Error'} = "$pkg: CheckIfTrayAvailable -> Wrong barcode type.";
    }

    return 0;
} #CheckIfTrayAvailable

sub CheckIfScanPlateAvailable {

    my ($self, $barcode, $ps_id) = @_;

    if($barcode =~ /^0j/) {
      my $used = $self->{'CheckIfAvailableScanPlateForSetup'} -> xSql($barcode);

      if(!$used) {
	  my $desc = $self->{'BarcodeDesc'}-> xSql($barcode);
	  if($desc =~ /Scan Plate/i) {
	    return $desc;
	  } else {
	    $self->{'Error'} = "$pkg: CheckIfScanPlateAvailable -> $barcode [$desc] is NOT Scan Plate!";
	    return 0;
	  }
      }
      $self->{'Error'} = "$pkg: CheckIfScanPlateAvailable -> Scan Plate is not available.";
    } else {
      $self->{'Error'} = "$pkg: CheckIfScanPlateAvailable -> Wrong barcode type.";
    }

    return 0;
} #CheckIfScanPlateAvailable

sub GetAvailClone {

    my ($self, $barcode, $ps_id, $direction, $status) = @_;
    
    my $lol = $self->{'GetAvailClone'} -> xSql($status, $barcode, $direction, $ps_id);
    
    if(defined $lol->[0][0]) {
	my $pses = [];

	my $lib = substr($lol->[0][0], 0, length($lol->[0][0]) - 3);
	
	foreach my $line (@$lol) {
	    my @inlist = grep(/^$line->[2]$/, @$pses);
	    push(@{$pses}, $line->[2]) if($#inlist == -1);
	}

	
	return ($lib, $pses);
    }

    $self->{'Error'} = "$pkg: GetAvailClone() -> $barcode, $ps_id, $direction, $status.";
    $self->{'Error'} = $self->{'Error'}." $DBI::errstr" if(defined $DBI::errstr);

    return 0;
}

sub GetAvailCloneGrowth {

    my ($self, $barcode, $ps_id, $direction, $status) = @_;
    
    my $lol = $self->{'GetAvailCloneGrowth'} -> xSql($status, $barcode, $direction, $ps_id);
    
    if(defined $lol->[0][0]) {
	my $pses = [];

	#my $lib = substr($lol->[0][0], 0, length($lol->[0][0]) - 3);
	#my $lib = $lol->[0][0];
	my $lib = $self->getCloneGrowthLibDescription($lol);
	foreach my $line (@$lol) {
	    my @inlist = grep(/^$line->[2]$/, @$pses);
	    push(@{$pses}, $line->[2]) if($#inlist == -1);
	}

	
	return ($lib, $pses);
    }

    $self->{'Error'} = "$pkg: GetAvailCloneGrowth() -> $barcode, $ps_id, $direction, $status.";
    $self->{'Error'} = $self->{'Error'}." $DBI::errstr" if(defined $DBI::errstr);

    return 0;
}

sub GetAvailCloneGrowthInScheduled {
    my ($self, $barcode, $ps_id) = @_;
    my $direction = 'in';
    my $status = 'scheduled';
    return $self->GetAvailCloneGrowth($barcode, $ps_id, $direction, $status);
}


sub GetAvailCloneInScheduled {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailClone($barcode, $ps_id, 'in', 'scheduled');
    
    return ($result, $pses);

}

sub GetAvailCloneOutScheduled {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailClone($barcode, $ps_id, 'out', 'scheduled');
    
    return ($result, $pses);

}

sub GetAvailCloneOutScheduled384{
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailClone($barcode, $ps_id, 'out', 'scheduled');
    
    return ($result);

}

sub GetAvailCloneInInprogress384 {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailClone($barcode, $ps_id, 'in', 'inprogress');
    
    return ($result, $pses);

}


sub GetAvailCloneOutInprogress {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'out', 'inprogress');
    
    return ($result, $pses);

}

sub GetAvailCloneGrowthInInprogress {

    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'in', 'inprogress');
    
    return ($result, $pses);

}



sub GetAvailCloneInInprogress {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailClone($barcode, $ps_id, 'in', 'inprogress');
    
    return ($result, $pses);

}

sub GetAvailCloneInOutInprogress {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'in', 'inprogress');
    if(! $result) {
      ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'out', 'inprogress');
    }
    return ($result, $pses);

}

sub GetAvailCloneInOutInprogressCompleted {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'in', 'inprogress');
    if(! $result) {
      ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'out', 'inprogress');
    }
    if(! $result) {
      ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'in', 'completed');
      if(! $result) {
        ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'out', 'completed');
      } 
    }
    return ($result, $pses);
}

#Check to see the culture slot is in progress.
sub GetAvailCloneCultureSlotInInprogress {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'in', 'inprogress');
    
    return $result;


}

sub GetAvailCloneLibInInprogress {
    
    my ($self, $barcode, $ps_id) = @_;
    #LSF: Check for empty barcode and return ('empty', [])
    #     This will support the non-barcoded plates on the 
    #     machine blend in with the barcoded plates.
    return ('NON-BARCODED', []) if($barcode eq 'empty');
    my ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'in', 'inprogress');
    
    return ($result, $pses);

}


## bjo: added to ensure this is no longer in a freezer
sub GetAvailCloneLibInInprogressOutOfFreezer {
    my ($self, $barcode, $ps_id) = @_;
    #LSF: Check for empty barcode and return ('empty', [])
    #     This will support the non-barcoded plates on the 
    #     machine blend in with the barcoded plates.
    return ('NON-BARCODED', []) if($barcode eq 'empty');

    my $bc = GSC::Barcode->get(barcode=>$barcode);
    my $fl = $bc->freezer_location;
     warn($fl);
    
    if ($fl ne "Not Found" && $fl !~ /^Retired/ ) {
	$self->{'Error'} = "This tray $barcode is still shown as checked into a freezer.  Please check it out first.";
	return undef;
    }

    my ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'in', 'inprogress');
    
    return ($result, $pses);


}

#LSF: Might need to add a new function to check for the culture slot when scan in the collection slot on the brinkmann prep.

sub GetAvailMachineInInprogress {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> {'GetAvailMachineInInprogress'}->xSql($barcode);
    
    #return ($result, $pses);
    return $result ? $result->[0][0] : undef;

}

sub GetEquipmentCollectionSlot {
    my ($self, $barcode, $ps_id) = @_;
  return $self->GetEquipmentSlot($barcode, "Collection Slot", "vacant");
}

sub GetEquipmentCultureSlot {
    my ($self, $barcode, $ps_id) = @_;
  return $self->GetEquipmentSlot($barcode, "Culture Slot", "vacant");
}

sub GetEquipmentOccupiedCultureSlot {
    my ($self, $barcode, $ps_id) = @_;
  return $self->GetEquipmentSlot($barcode, "Culture Slot", "occupied");
}

sub GetAvailEquipmentSlotInInprogress {
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> {'GetAvailEquipmentSlotInInprogress'}->xSql($barcode);
    
    return $result;
}

sub GetEquipmentSlot {
    
    my ($self, $barcode, $type, $status) = @_;
    
    #my ($result, $pses) = $self -> {'GetEquipmentSlot'}->xSql($barcode, $type, $status);
    my ($result, $pses) = $self -> {'GetEquipmentSlot'}->xSql($barcode, $type, $barcode, $type);
    
    #return ($result, $pses);
    return $result;

}

sub GetAvailCloneBrinkmannInInprogress {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'in', 'inprogress');
    
    return ($result, $pses);

}

sub GetAvailCloneInCompOrInprog {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'in', 'inprogress');
    if(!$result) {
	($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'in', 'completed');
    }
    return ($result, $pses);

}

sub GetAvailCloneOutCompOrOutprog {
    
    my ($self, $barcode, $ps_id) = @_;
    
    my ($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'out', 'inprogress');
    if(!$result) {
	($result, $pses) = $self -> GetAvailCloneGrowth($barcode, $ps_id, 'out', 'completed');
    }
    return ($result, $pses);

}

sub CompletePses {

    my ($self, $pses) = @_;

    foreach my $pse_id (@{$pses}) {
	
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pse_id);
	return 0 if($result == 0);
    }

    return 1;
    
}
sub GetAvailCloneCyclePlate {

    my ($self, $barcode) = @_;
    
    my $lol = $self->{'GetAvailCloneCyclePlate'} -> xSql($barcode);
    
    if(defined $lol->[0][0]) {
	my $pses = [];

	#my $lib = substr($lol->[0][0], 0, length($lol->[0][0]) - 3);
	#my $lib = $lol->[0][0];
	my $lib = $self->getCloneGrowthLibDescription($lol);
	foreach my $line (@$lol) {
	    my @inlist = grep(/^$line->[2]$/, @$pses);
	    push(@{$pses}, $line->[2]) if($#inlist == -1);
	}

	
	return ($lib, $pses);
    }

    $self->{'Error'} = "$pkg: GetAvailCloneCyclePlate() -> Cycle plate $barcode not available.";
    $self->{'Error'} = $self->{'Error'}." $DBI::errstr" if(defined $DBI::errstr);

    return 0;
}

sub GetAvailCloneCyclePlateReloading {

    my ($self, $barcode) = @_;
    
    my $lol = $self->{'GetAvailCloneCyclePlateForReload'} -> xSql($barcode);
    
    if(defined $lol->[0][0]) {
	my $pses = [];

	#my $lib = substr($lol->[0][0], 0, length($lol->[0][0]) - 3);
	my $lib = $self->getCloneGrowthLibDescription($lol);
	
	foreach my $line (@$lol) {
	    my @inlist = grep(/^$line->[2]$/, @$pses);
	    push(@{$pses}, $line->[2]) if($#inlist == -1);
	}

	
	return ($lib, $pses);
    }

    $self->{'Error'} = "$pkg: GetAvailCloneCyclePlate() -> Cycle plate $barcode not available.";
    $self->{'Error'} = $self->{'Error'}." $DBI::errstr" if(defined $DBI::errstr);

    return 0;
}

sub GetAvailDigestLoading {

    my ($self, $barcode, $ps_id) = @_;
 
    my $desc;
    my $pses = [];
    
    if($self->{'ActiveScanPosition'} == 0) {
	$desc = $self->{'BarcodeDesc'}-> xSql($barcode);
	if($desc =~ /gel rig/i) {
	  $self -> {'DigestGelPosition'} = $desc;
	} else {
	  $self->{'ActiveScanPosition'} = 0;
          $self->{'Error'} = "$pkg: GetAvailDigestLoading() -> $barcode is NOT a gel rig!";
          return 0;
	}
    }
    else {
	if($barcode =~ /^empty/) { 
	    $desc = $barcode ;
	}
	else {
	    ($desc, $pses) = $self -> GetAvailCloneCyclePlate($barcode);
	    $desc = undef if($desc eq '0');
	}
    }
    
    if(defined $desc) {
	$self->{'ActiveScanPosition'}++;
	$self->{'ActiveScanPosition'}= 0 if($self->{'ActiveScanPosition'} == 2);
	
	return ($desc, $pses);
    }
    
    $self->{'Error'} = "$pkg: GetAvailDigestLoading() -> Could not get description for $barcode.";
    return 0;
}

sub GetAvailDigestReLoading {

    my ($self, $barcode, $ps_id) = @_;
 
    my $desc;
    my $pses = [];
    
    #if($self->{'ActiveScanPosition'} == 0) {
    #	$desc = $self->{'BarcodeDesc'}-> xSql($barcode);
    #	$self -> {'DigestGelPosition'} = $desc;
    #}
    #else {
	if($barcode =~ /^empty/) { 
	    $desc = $barcode ;
	}
	else {
	    ($desc, $pses) = $self -> GetAvailCloneCyclePlateReloading($barcode);
	    $desc = undef if($desc eq '0');
	}
    #}
    
    if(defined $desc) {
    #	$self->{'ActiveScanPosition'}++;
    #	$self->{'ActiveScanPosition'}= 0 if($self->{'ActiveScanPosition'} == 2);
	
	return ($desc, $pses);
    }
    
    $self->{'Error'} = "$pkg: GetAvailDigestLoading() -> Could not get description for $barcode.";
    return 0;
}

sub CheckIfGelPosition {

    my ($self, $barcode) = @_;

    my $gel_info = $self->{'GetAvailGelPsePosition'} -> xSql($barcode);
    my $desc;
    
    if(defined $gel_info->[0][0]) {
      $desc = "digest gel -> $gel_info->[0][1]";
    } else {
      return 0;
    }

    my $pos = $self -> {'DigestGelPosition'};
    #The $pos contains the "Gel Rig 1 top" or "Gel Rig 1 bottom"information
    #But, the gel_info->[0][1] contains "top" or "bottom" information
    if($pos =~ /$gel_info->[0][1]$/) {
	return $desc;
    }
    else {
    	$self->{'Error'} = "$pkg: CheckIfRigAvailable -> Rig Position does not match Gel Position = $pos.";
    }
    return 0;
} #CheckIfRigAvailable

sub CheckIfAvailReagent {

    my ($self, $barcode, $ps_id) = @_;

    my $process = Query($self->{'dbh'}, qq/select pro_process_to from process_steps where ps_id = $ps_id/);
    my $name = Query($self->{'dbh'}, qq/select rn_reagent_name from reagent_informations where bs_barcode = '$barcode'/);

    if(($name eq '3M KOAc pH 5.5')&&($process eq 'record potassium acetate pH')) {
	return $name;
    }
    if(($name eq '50X TAE 2 L')&&($process eq 'dilute buffer')) {
	return $name;
    }

    $self -> {'Error'} = "$pkg: CheckIfAvailReagent() -> $barcode is not potassium acetate.";
    
    return 0;
}
############################################################
# Is this the Next Available slot on the carousel?         #
############################################################
sub isThisNextAvailableSlot {
  my ($self, $barcode) = @_;
  my $lol = $self->{'IsThisNextAvailableSlot'} -> xSql($barcode);
  
  my $min;
  my $bc;
  if(defined $lol->[0][0]) {
    foreach my $data (@{$lol}) {
      if(defined $min) {
        if($data->[1] < $min) {
          $bc = $data->[0];
          $min = $data->[1];
	}
      } else {
        $bc = $data->[0];
        $min = $data->[1];
      }
    }
  }
  return $bc eq $barcode ? 1 : 0;

}

sub CheckAvailStreak {
    my ($self, $barcode) = @_;

    my $slist = $self->{'GetAvailableStreaks'} -> xSql($barcode);
    
    if (defined $slist->[0][0]) {
	return $barcode;
    } else {
	$self->{'Error'} = "$pkg: GetAvailableStreaks() -> No sources requested for this tray";
	return 0;
    }
    

}

sub GetAvailableStreaks {
    my ($self, $barcode) = @_;
	
    if ( @{$::BarcodeMgr->Get('UsedInputBarcodes')} eq 1) {
	$self->{STREAK_INPUT_PTR} = 0;
	$self->{STREAK_INPUT_LIST} = [];
	$self->{STREAK_INPUT_BY_BC} = {};
    }

    my $slist = $self->{'GetAvailableStreaks'} -> xSql($barcode);
    my $odl;
    
    if (defined $slist->[0][0]) {
	foreach (@$slist) {
	    my ($pse, $inbc, $outbc, $dna, $well, $dlid) = @$_;
	    my $inbcrec = {streak_pse_id=>$pse,
			   input_barcode=>$inbc,
			   output_barcode=>$outbc,
			   source_dna=>$dna,
			   source_dl_id=>$dlid};
	    push @{$self->{STREAK_INPUT_LIST}}, $inbcrec;
	    push @{$self->{STREAK_INPUT_BY_BC}->{$inbc}}, $inbcrec;

	    push @$odl, "SOURCE: $dna -- $well\n";
	}
	
	return $odl;
    }

    $self -> {'Error'} = "$pkg: GetAvailableStreaks() -> could not find any streak possibilities for this tray";
    return 0;
}

sub CheckStreakPtr {
    my ($self, $barcode) = @_;

    if ($barcode eq "empty") {
	$self->{STREAK_INPUT_PTR} += 1;
	return "-- not streaking this";
    }

    my $n = $self->{STREAK_INPUT_PTR};
    my $ink = $self->{STREAK_INPUT_LIST}->[$n];
    
    if ($ink && $ink->{output_barcode} eq $barcode) {
	$self->{STREAK_INPUT_PTR} += 1;
	return GSC::Barcode->get($barcode)->barcode_description;
    }else {
	$self->{'Error'} = "$pkg: CheckStreakPtr() -> $barcode is not the correct output barcode to use for this streak source.";
	return 0;
    }    
}

sub ConfirmScheduledStreak {
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my $in_bc = $bars_in->[0];

    my @pses;

    for (my $idx = 0; $idx < scalar @$bars_out; $idx++) {
	next if ($bars_out->[$idx] =~ /^empty/);

	my $rec = $self->{STREAK_INPUT_BY_BC}->{$in_bc}->[$idx];
	



	if ($bars_out->[$idx] ne $rec->{output_barcode}) {
	    $self->{'Error'} = "$pkg: ConfirmScheduledStreak() -> output barcode does not match expected, validation failed";
	}
	if ($bars_out->[$idx] ne $rec->{input_barcode}) {
	    $self->{'Error'} = "$pkg: ConfirmScheduledStreak() -> input barcode does not match expected, validation failed";
	}

	my $pse = GSC::PSE->get($rec->{streak_pse_id});

	my $tpp_src = GSC::TppPSE->get(pse_id=>$pse->pse_id,
				       barcode=>$rec->{input_barcode});
	
	my $prior_pse = GSC::PSE->get($tpp_src->prior_pse_id);
	$prior_pse->pse_status("completed");
	$prior_pse->pse_result("successful");
	$prior_pse->date_completed(App::Time->now());
	
	$pse->ei_id($emp_id);
	$pse->pse_status("inprogress");
	GSC::Barcode->get($bars_out->[$idx])->content_description($rec->{source_dna});
	
	push @pses, $pse->pse_id;
    }    
    return \@pses;
}


############################################################
# Get the Available quadrants for a 384 plate to inoculate #
############################################################
sub GetAvailableQuads {

    my ($self, $barcode) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
    my $lol = $self->{'GetAvailableQuadsPses'} -> xSql($barcode);
   
    if(defined $lol->[0][0]) {
	my $quads = [];
	foreach my $quad (@{$lol}) {
	    push(@{$quads}, $quad->[0]);
	}
	
	return $quads;
    }

    $self -> {'Error'} = "$pkg: GetAvailableQuads() -> Could not find available quadrants.";
    return 0;
} #GetAvailableQuads


sub GetAvailableQuadsIn {

 my ($self, $barcode) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
    my $lol = $self->{'GetAvailableQuadsPsesIn'} -> xSql($barcode,384);
   
    if(defined $lol->[0][0]) {
	my $quads = [];
	foreach my $quad (@{$lol}) {
	    push(@{$quads}, $quad->[0]);
	}
	
	return $quads;
    }
 else{
     $lol =  $self->{'GetAvailableQuadsPsesIn'} -> xSql($barcode,96);
     if(defined $lol->[0][0]) {
	my $quads = [];
	foreach my $quad (@{$lol}) {
	    push(@{$quads}, $quad->[0]);
	}
	
	return $quads;
    }   
 }
 
 
    $self -> {'Error'} = "$pkg: GetAvailableQuadsIn() -> Could not find available quadrants.";
    return 0;
} #GetAvailableQuadsIn


sub GetAvailableEnzymes {

    my ($self, $barcode) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
    my $lol = $self->{'GetAvailableEzymesPses'} -> xSql($barcode);
   
    if(defined $lol->[0][0]) {
	my $quads = [];
	foreach my $quad (@{$lol}) {
	    push(@{$quads}, $quad->[0]);
	}
	
	return $quads;
    }

    $self -> {'Error'} = "$pkg: GetAvailableEnzymes() -> Could not find available enzyme.";
    return 0;

} #GetAvailableEnzymes




sub SetupBlock384 {
    
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i = 0;

    my $quads_pses = $self -> GetAvailableQuadsPses($bars_in->[0]);
    
    foreach my $row (@{$quads_pses}) {
	
	my $sector = $row->[0];
	if(! defined $sector) {
	    $self->{'Error'} = "Could not find a valid sector.";
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
	
	my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out], $emp_id);
	
	#my $result = $self -> CloneTrans384To96($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	my $result = $self -> CloneTrans384To96ForNewGrowth($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	return 0 if($result == 0);
	
	$i++;
	push(@{$pse_ids}, $new_pse_id);

    }
    
    return $pse_ids;
} #SetupBlock384


sub SetupBlockIn {
    
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i = 0;
    my @pbs = GSC::PSEBarcode->get(barcode => $bars_in->[0], direction => 'out');
    my $quads_pses;
    my $is384 = 0; 
    if(@pbs) {
      my @dps = GSC::DNAPSE->get(pse_id => \@pbs);
      if(@dps) {
        my $dl_id = GSC::DNALocation->get(dl_id => $dps[0]->dl_id);
        $quads_pses = $self -> GetAvailableQuadsPsesIn($bars_in->[0],($dl_id->location_type eq "384 well plate" ? 384 : 96));
	$is384 = $dl_id->location_type eq "384 well plate" ? 1 : 0;
      }
    } else {
      $quads_pses = $self -> GetAvailableQuadsPsesIn($bars_in->[0],(@$pre_pse_ids == 4 ? 384 : 96));
      $is384 = @$pre_pse_ids == 4 ? 1 : 0;
    }  
    foreach my $row (@{$quads_pses}) {
	
	my $sector = $row->[0];
	if(! defined $sector) {
	    $self->{'Error'} = "Could not find a valid sector.";
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
	
	my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out], $emp_id);
	#if(@$quads_pses == 4){ #- 384 well plate
	if($is384){ #- 384 well plate
	    #my $result = $self -> CloneTrans384To96($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	    my $result = $self -> CloneTrans384To96ForNewGrowth($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	    return 0 if($result == 0);
	}
	else{ #- 96 well plate
	    #my $result = $self -> CloneTrans384To96($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	    my $result = $self -> CloneTrans96To96ForNewGrowth($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	    return 0 if($result == 0);
	}
	
	$i++;
	push(@{$pse_ids}, $new_pse_id);

    }
    
    return $pse_ids;
} #SetupBlock384In

sub SetupBlockIn_scheduled {
    
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i = 0;
    my @pbs = GSC::PSEBarcode->get(barcode => $bars_in->[0], direction => 'out');
    my $quads_pses;
    my $is384 = 0; 
    if(@pbs) {
      my @dps = GSC::DNAPSE->get(pse_id => \@pbs);
      if(@dps) {
        my $dl_id = GSC::DNALocation->get(dl_id => $dps[0]->dl_id);
        $quads_pses = $self -> GetAvailableQuadsPsesIn($bars_in->[0],($dl_id->location_type eq "384 well plate" ? 384 : 96));
	$is384 = $dl_id->location_type eq "384 well plate" ? 1 : 0;
      }
    } else {
      $quads_pses = $self -> GetAvailableQuadsPsesIn($bars_in->[0],(@$pre_pse_ids == 4 ? 384 : 96));
      $is384 = @$pre_pse_ids == 4 ? 1 : 0;
    }  
    foreach my $row (@{$quads_pses}) {
	
	my $sector = $row->[0];
	if(! defined $sector) {
	    $self->{'Error'} = "Could not find a valid sector.";
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
	
	my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out], $emp_id);
=cut
	#if(@$quads_pses == 4){ #- 384 well plate
	if($is384){ #- 384 well plate
	    #my $result = $self -> CloneTrans384To96($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	    my $result = $self -> CloneTrans384To96ForNewGrowth($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	    return 0 if($result == 0);
	}
	else{ #- 96 well plate
	    #my $result = $self -> CloneTrans384To96($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	    my $result = $self -> CloneTrans96To96ForNewGrowth($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	    return 0 if($result == 0);
	}
=cut
        	
	$i++;
	#LSF: Changed the PSEs to scheduled status.
	my $np = GSC::PSE->get(pse_id => $new_pse_id);
	$np->pse_status('scheduled');
	push(@{$pse_ids}, $new_pse_id);

    }
    
    return $pse_ids;
} #SetupBlock384In

sub SetupBlock384ForDNAResourceItem {
    
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i = 0;

    my ($lib, $ref_pses) = $self -> GetAvailCloneInInprogress($bars_in->[0], $ps_id);
    
    my $pre_pse_id = $ref_pses->[0];
    
    foreach my $sector ('a1','a2','b1','b2') {
		    
	my $bar_out = $bars_out->[$i];
	if(! defined $bar_out) {
	    $self -> {'Error'} = "Could not find a output barcode.";
	}
	
	my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out], $emp_id);
	
	#my $result = $self -> CloneTrans384To96($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	my $result = $self -> CloneTrans384To96ForNewGrowth($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	return 0 if($result == 0);
	
	$i++;
	push(@{$pse_ids}, $new_pse_id);

    }
    
    return $pse_ids;
} #SetupBlock384ForDNAResourceItem



sub SetupBlock96 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $update_status = 'completed';
    my $update_result = 'successful';
    
    my $pre_pse_id = $pre_pse_ids->[0];
    if(! defined $pre_pse_id) {
	$self -> {'Error'} = "Could not find a valid pre_pse_id.";
    }
    
    my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);

    my $result = $self -> CloneTrans96To96ForNewGrowth($bars_in->[0], $pre_pse_id, $new_pse_id);
    return 0 if($result == 0);
    
    return [$new_pse_id];

}

sub SetupBlockFromStreak {
    
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i = 0;

    my $quads_pses = $self -> GetAvailableQuadsPses($bars_in->[0]);
    
    foreach my $row (@{$quads_pses}) {
	
	my $sector = $row->[0];
	if(! defined $sector) {
	    $self->{'Error'} = "Could not find a valid sector.";
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
	
	my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out], $emp_id);
	
	my $result = $self -> CloneTransStreakTo96($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	return 0 if($result == 0);
	
	$i++;
	push(@{$pse_ids}, $new_pse_id);

    }
    
    return $pse_ids;
} #SetupBlockFromStreak


sub Streak384 {
    
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i = 0;

    my $quads_pses = $self -> GetAvailableQuadsPses($bars_in->[0]);
    
    foreach my $row (@{$quads_pses}) {
	
	my $sector = $row->[0];
	if(! defined $sector) {
	    $self->{'Error'} = "Could not find a valid sector.";
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
	
	my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [$bar_out], $emp_id);
	
	my $result = $self -> CloneTrans96To96($bars_in->[0], $pre_pse_id, $new_pse_id, $sector);
	return 0 if($result == 0);
	
	$i++;
	push(@{$pse_ids}, $new_pse_id);

    }
    
    return $pse_ids;
} #Streak384



sub CloneTransfer96Complete {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my ($pses) = $self -> CloneTransfer96($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids);

    foreach my $pse (@$pses) {
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pse);
	return 0 if($result == 0);
    }

    return $pses;
}

sub CloneTransfer96WithNoCompletionComplete {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    
    my ($pses) = $self -> CloneTransfer96WithNoCompletion($ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids);

    foreach my $pse (@$pses) {
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pse);
	return 0 if($result == 0);
    }

    return $pses;
}

sub CloneTransfer96 {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $update_status = 'completed';
    my $update_result = 'successful';
    
    my $pre_pse_id = $pre_pse_ids->[0];
    if(! defined $pre_pse_id) {
	$self -> {'Error'} = "Could not find a valid pre_pse_id.";
    }
    
    my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);

    my $result = $self -> CloneTrans96To96($bars_in->[0], $pre_pse_id, $new_pse_id);
    return 0 if($result == 0);
    
    return [$new_pse_id];

}

sub CloneTransfer96WithNoCompletion {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $update_status = '';
    my $update_result = '';
    
    my $pre_pse_id = $pre_pse_ids->[0];
    if(! defined $pre_pse_id) {
	$self -> {'Error'} = "Could not find a valid pre_pse_id.";
    }
    
    my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);

    my $result = $self -> CloneTrans96To96($bars_in->[0], $pre_pse_id, $new_pse_id);
    return 0 if($result == 0);
    
    return [$new_pse_id];

}

=head1 CloneTransfer96WithEquipment

Clone transfer 96 with the equipment tight to the plate.

=cut

sub CloneTransfer96WithEquipment {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $update_status = 'completed';
    my $update_result = 'successful';
    
    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});
    my @npse;
    for(my $i = 0; $i < @{$bars_out}; $i ++) {
      
      #LSF: Skip the empty barcode  to support non-barcoded and barcoded plates blended together.
      next if($bars_out->[$i] =~ /^empty/);
      
      my $pre_pse_id = $pre_pse_ids->[$i];
      if(! defined $pre_pse_id) {
	  $self -> {'Error'} = "Could not find a valid pre_pse_id.";
      }
      my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_out->[$i], [$bars_in->[$i + 1]], $emp_id);

      #my $result = $self -> CloneTrans96To96($bars_in->[0], $pre_pse_id, $new_pse_id);
      my $result = $self -> CloneTrans96To96($bars_out->[$i], $pre_pse_id, $new_pse_id);
      return 0 if($result == 0);
      #$result = $self->AssignEquipment($bars_in->[$i + 1], $pre_pse_id, $new_pse_id);
      my $result = $TouchSql -> EquipmentEvent($new_pse_id, $bars_in->[$i + 1]);
      if(!$result) {
	 $self->{'Error'} = $TouchScreen::TouchSql::Error;
	 return 0;
      }
      push @npse, $new_pse_id;
    }
    return \@npse;

}

=head1 CloneTransfer96WithEquipment

Clone transfer 96 with the equipment tight to the plate.

=cut

sub CloneTransfer96OutWithEquipment {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $update_status = 'completed';
    my $update_result = 'successful';
    
    my @npse;
    for(my $i = 0; $i < @{$bars_out}; $i ++) {
      my $pre_pse_id = $pre_pse_ids->[$i];
      if(! defined $pre_pse_id) {
	  $self -> {'Error'} = "Could not find a valid pre_pse_id.";
      }
      #LSF: I need the barcode.
      my $pse_id = $self->{GetAvailPseOnMachine}->xSql($bars_in->[$i + 1]);
      $pre_pse_id = $pse_id->[0][0] if($pse_id->[0][0]);
      #LSF: Get the barcode for the beckman block.
      my($pre_barcode_info) = $self->{GetEquipmentSlotPlateBarcodePse}->xSql($bars_in->[$i + 1]);
      return 0 if(! defined $pre_barcode_info->[0][0]);
      my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $pre_barcode_info->[0][0], [$bars_out->[$i]], $emp_id);

      #my $result = $self -> CloneTrans96To96($bars_in->[0], $pre_pse_id, $new_pse_id);
      #my $result = $self -> CloneTrans96To96($bars_out->[$i], $pre_pse_id, $new_pse_id);
      my $result = $self -> CloneTrans96To96($pre_barcode_info->[0][0], $pre_pse_id, $new_pse_id);
      return 0 if($result == 0);
      #$result = $self->VacantEquipment($bars_in->[$i + 1], $pre_pse_id, $new_pse_id);
      #my $result = $TouchSql -> EquipmentEvent($pre_pse_id, $bars_in->[$i + 1]);
      #if(!$result) {
      #	 $self->{'Error'} = $TouchScreen::TouchSql::Error;
      #	 return 0;
      #}
      
      my $tp = GSC::TransferPattern->get(transfer_name => '96 well transfer');
      
      my $tpse1 = GSC::TppPSE->create(prior_pse_id => $pre_pse_id,
                                      tp_id => $tp,
                                      container_position => '1',
                                      pse_id => $new_pse_id,
                                      barcode => $pre_barcode_info->[0][0]
                                      ) or return;

      my $tpse2 = GSC::TppPSE->create(prior_pse_id => '1',
                                      tp_id => $tp,
                                      container_position => '2',
                                      pse_id => $new_pse_id,
                                      barcode => $bars_out->[$i]) or return;

      my $pse = GSC::PSE->get($new_pse_id);
      $pse->tp_id($tp->tp_id);

      push @npse, $new_pse_id;
    }
    return \@npse;

}


sub CloneTransferGel {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $update_status = 'completed';
    my $update_result = 'successful';
    
    my $pre_pse_id = $pre_pse_ids->[0];
    if(! defined $pre_pse_id) {
	$self -> {'Error'} = "Could not find a valid pre_pse_id.";
    }
    
    my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);

    my $result = $self -> CloneTransGelToGel($bars_in->[0], $pre_pse_id, $new_pse_id);
    return 0 if($result == 0);
    
    return [$new_pse_id];

}


sub RecordPH {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'completed', 'successful', $emp_id, 0, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$new_pse_id);
 
    return [$new_pse_id];

}

sub DiluteBuffer {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my ($pses) = Lquery($self->{'dbh'}, qq/select distinct pse_id from process_step_executions, pse_barcodes where
				pse_id = pse_pse_id and
				ps_ps_id = $ps_id and
				direction = 'in' and
				psesta_pse_status = 'inprogress'/);

    foreach my $pse (@$pses) {
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pse);
	return 0 if($result == 0);
    }

    
    
    
    my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'inprogress', '', $emp_id, 0, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$new_pse_id);
    
    return [$new_pse_id];
   


} #DiluteBuffer


##########################################################
# Log a transfer from 384 to 96 subclone locations event #
##########################################################
sub CloneTrans384To96 {

    my ($self, $barcode, $pre_pse_id, $new_pse_id, $sector) = @_;

    my $lol;
    
    if ($sector) {
	$lol =  $self -> {'GetCloPlIdFromClonePseSector'} -> xSql($barcode, $sector, $pre_pse_id);
    } else {
	$lol =  $self -> {'GetCloPlIdFromClonePse'} -> xSql($barcode, $pre_pse_id);
    }

    return 0 if(! defined $lol->[0][0]);
    
    # get sector id for a1
    my $sec_id= $self -> Process('GetSectorId', 'a1');
    return ($self->GetCoreError) if(!$sec_id);
    
    # get pt_id from 96 well plate
    my $pt_id = $self -> Process('GetPlateTypeId', '96');
    return 0 if($pt_id == 0);

    foreach my $row (@{$lol}) {
	my $clo_id = $row->[0];
	my $well_384 = $row->[1];
	
	my ($well_96, $sector) = &ConvertWell::To96($well_384);

	my $pl_id = $self->GetPlId($well_96, $sec_id, $pt_id);
	return 0 if($pl_id eq '0');

#	my $result = $self -> InsertClonesPsesWell($clo_id, $new_pse_id, $pl_id);
	my $result = $self -> InsertDNAPSE($clo_id, $new_pse_id, $pl_id);


	return 0 if($result == 0);
	
    }
    
    return 1;

} #CloneTrans384To96

##########################################################
# Log a transfer from 384 to 96 subclone locations event #
##########################################################
sub CloneTrans384To96ForNewGrowth {

    my ($self, $barcode, $pre_pse_id, $new_pse_id, $sector) = @_;

    my $lol;

    if ($sector) {
	$lol = $self -> {'GetCloPlIdFromClonePseSector'} -> xSql($barcode, $sector, $pre_pse_id);
    } else {
	$lol =  $self -> {'GetCloPlIdFromClonePse'} -> xSql($barcode, $pre_pse_id);
    }
    return 0 if(! defined $lol->[0][0]);
    
    # get sector id for a1
=head1    
    my %sc = (
      'a1' => $self -> Process('GetSectorId', 'a1'),
      'a2' => $self -> Process('GetSectorId', 'a2'),
      'b1' => $self -> Process('GetSectorId', 'b1'),
      'b2' => $self -> Process('GetSectorId', 'b2'),
    );
    print Dumper(%sc);
    return ($self->GetCoreError) if(! ($sc{'a1'} && $sc{'a2'} && $sc{'b1'} && $sc{'b2'}));
=cut
    #my $sec_id = $self -> Process('GetSectorId', 'a1');
    #return ($self->GetCoreError) if(! $sec_id);
    # get pt_id from 96 well plate
    #my $pt_id = $self -> Process('GetPlateTypeId', '96');
    
    my %dl = %{{ map +( $_->location_name => $_ ), GSC::DNALocation->get(location_type => '96 well plate') }};
    
    #return 0 if($pt_id == 0);
	
    my $libSql = TouchScreen::LibSql->new($self->{dbh}, $self->{Schema});
    my $cle = $self->GetNextGrowthExtForClone_array([ map { $_->[0] } @$lol]);
    foreach my $row (@{$lol}) {
	my $clo_id = $row->[0];
	my $well_384 = $row->[1];
	
	my ($well_96, $sector) = &ConvertWell::To96($well_384);
	#$sector =~ s/([a-z])0/\1/g;
	#my $pl_id = $self->GetPlId($well_96, $sc{$sector}, $pt_id);
	my $pl_id = $dl{$well_96} ? $dl{$well_96}->dl_id : 0;
	#my $pl_id = $self->GetPlId($well_96, $sec_id, $pt_id);
	return 0 if($pl_id eq '0');

	#New growth stuff
	#Need to change this to find the $old_cg_id
	#my ($clo_id, $old_cg_id) = $self->GetCloneIdForNewGrowth($pre_pse_ids->[0]);
	#return 0 if((!$clo_id) && (!defined $old_cg_id));
	#$clo_id will be the parent of the new growth; therefore, the $old_cg_id is not defined.
	my $old_cg_id;
	
	#my $growth_ext = $libSql->GetNextGrowthExtForClone($clo_id);
	my $growth_ext = GSC::CloneGrowth->next_growth_ext(clo_id => $clo_id);
#	my @e = keys %{$cle->{$clo_id}} if($cle && $cle->{$clo_id});
#	my $growth_ext = $self->next_growth_ext(@e); 
	return 0 if(!$growth_ext);
	
	my $cg_id = $libSql->GetNextCgId;
	return 0 if(!$cg_id);
	
	my $result = $libSql->InsertCloneGrowths($cg_id, $growth_ext, $clo_id, "unknown", $old_cg_id, 'production', $new_pse_id, $pl_id);
	return 0 if(!$result);

#Since the DNA pse cannot handle it.  The dl location will be updated manually.	
#	$result = $self-> InsertDNAPSE($cg_id, $new_pse_id, $dl_id);
	
	#$result = App::DB->sync_database();
	#if(!$result) {
	#    $self -> {'Error'} = "Failed trying to sync\n";
	#    return 0;
	#}	
	#End

#	my $result = $self -> InsertClonesPsesWell($clo_id, $new_pse_id, $pl_id);
	#my $result = $self -> InsertDNAPSE($clo_id, $new_pse_id, $pl_id);
	#my $result = $self -> InsertDNAPSE($cg_id, $new_pse_id, $pl_id);
        #$result = $self->{'UpdateDNAPseLocation'}->xSql($pl_id, $cg_id, $new_pse_id);	
	#return 0 if(!$result);


	#return 0 if($result == 0);
	
    }
    my $result = App::DB->sync_database();
    if(!$result) {
	$self -> {'Error'} = "Failed trying to sync\n";
	return 0;
    }	
    
    return 1;

} #CloneTrans384To96

##########################################################
# Log a transfer from 96  to 96 subclone locations event #
##########################################################
sub GetNextGrowthExtForClone_array {
    my ($self, $clo_ids) = @_;
    my $dbh = $self ->{'dbh'};
    my $schema = $self->{'Schema'};
    #LSF: Do the hard way.
    my %gs;
    my @cgs = GSC::CloneGrowth->get(clo_id => $clo_ids);
    foreach my $cg (@cgs) {
      $gs{$cg->clo_id}->{$cg->growth_ext} = $cg;
    }
    return \%gs;
    
} #GetNextGrowthExtForClone

sub next_growth_ext {
    my $self = shift;
    my @gexts = (@_);
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

}

sub CloneTrans96To96ForNewGrowth {

    my ($self, $barcode, $pre_pse_id, $new_pse_id) = @_;

    my $lol =  $self -> {'GetCloPlIdFromClonePse'} -> xSql($barcode, $pre_pse_id);
    return 0 if(! defined $lol->[0][0]);

    my $libSql = TouchScreen::LibSql->new($self->{dbh}, $self->{Schema});

    foreach my $row (@{$lol}) {
	my $clo_id = $row->[0];
	my $well_96 = $row->[1];
	my $pl_id = $row->[2];
	
	#New growth stuff
	#Need to change this to find the $old_cg_id
	#my ($clo_id, $old_cg_id) = $self->GetCloneIdForNewGrowth($pre_pse_ids->[0]);
	#return 0 if((!$clo_id) && (!defined $old_cg_id));
	#$clo_id will be the parent of the new growth; therefore, the $old_cg_id is not defined.
	my $old_cg_id;
	
	my $growth_ext = $libSql->GetNextGrowthExtForClone($clo_id);
	return 0 if(!$growth_ext);
	
	my $cg_id = $libSql->GetNextCgId;
	return 0 if(!$cg_id);
	
	my $result = $libSql->InsertCloneGrowths($cg_id, $growth_ext, $clo_id, "unknown", $old_cg_id, 'production', $new_pse_id, $pl_id);
	return 0 if(!$result);
    }
    my $result = App::DB->sync_database();
    if(!$result) {
	$self -> {'Error'} = "Failed trying to sync\n";
	return 0;
    }	
    
    return 1;

} #CloneTrans96To96ForNewGrowth


##########################################################
# Log a transfer from 96 to 96 subclone locations event #
##########################################################
sub CloneTrans96To96 {
    
    my ($self, $barcode, $pre_pse_id, $new_pse_id) = @_;
    
    my $lol =  $self -> {'GetCloPlIdFromClonePse'} -> xSql($barcode, $pre_pse_id);
    return 0 if(! defined $lol->[0][0]);
    
    foreach my $row (@{$lol}) {
	my $clo_id = $row->[0];
	my $well_96 = $row->[1];
	my $pl_id = $row->[2];

	#my $result = $self -> InsertClonesPsesWell($clo_id, $new_pse_id, $pl_id);
	my $result = $self -> InsertDNAPSE($clo_id, $new_pse_id, $pl_id);
	return 0 if($result == 0);
	
    }
    
    return 1;

} #CloneTrans96To96

##########################################################
# Edit equipment to the plate event #
##########################################################
sub AssignEquipment {
  my ($self, $barcode, $pre_pse_id, $new_pse_id) = @_;
  return $self->EditEquipment($barcode, $pre_pse_id, $new_pse_id, 'occupied');
}
##########################################################
# Edit equipment to the plate event #
##########################################################
sub EditEquipment {
    my ($self, $barcode, $pre_pse_id, $new_pse_id, $status) = @_;
    #Add the equipment to the plate.
    #Indicate the equipment is occupied
    my $sth = $self->{'dbh'}->prepare(qq/DECLARE
       vBS_BARCODE EQUIPMENT_INFORMATIONS.BS_BARCODE%TYPE;
       vPSE_ID PROCESS_STEP_EXECUTIONS.PSE_ID%TYPE;
       vEIS_EQUIPMENT_STATUS EQUIPMENT_INFORMATIONS.EIS_EQUIPMENT_STATUS%TYPE;
     BEGIN
       vBS_BARCODE := ?;
       vPSE_ID := ?;
       vEIS_EQUIPMENT_STATUS := ?;
       insert into pse_equipment_informations (EQUINF_BS_BARCODE, PSE_PSE_ID) values (vBS_BARCODE, vPSE_ID);
       update equipment_informations set EIS_EQUIPMENT_STATUS = vEIS_EQUIPMENT_STATUS where BS_BARCODE = vBS_BARCODE;
     END;/);
    $sth->execute($barcode, $new_pse_id, $status) or return 0;
    #my $result =  $self -> {'EditPlateToEquipment'} -> xSql($barcode, $new_pse_id, 'occupied');
    return 1;
} #AssignEquipment

##########################################################
# Vacant equipment to the plate event #
##########################################################
sub VacantEquipment {
  my ($self, $barcode, $pre_pse_id, $new_pse_id) = @_;
  return $self->EditEquipment($barcode, $pre_pse_id, $new_pse_id, 'vacant');
} #AssignEquipment

##########################################################
# Log a transfer from 96 to 96 subclone locations event #
##########################################################
sub CloneTransStreakTo96 {
    
    my ($self, $barcode, $pre_pse_id, $new_pse_id) = @_;
    
    my $lol =  $self -> {'GetCloPlIdFromClonePse'} -> xSql($barcode, $pre_pse_id);
    return 0 if(! defined $lol->[0][0]);
 
    my $sec_id= $self -> Process('GetSectorId', 'a1');
    return ($self->GetCoreError) if(!$sec_id);
    
    # get pt_id from 96 well plate
    my $pt_id = $self -> Process('GetPlateTypeId', '96');
    return 0 if($pt_id == 0);
    
    foreach my $row (@{$lol}) {
	my $clo_id = $row->[0];
	my $well_384 = $row->[1];

	my ($well_96, $streak_subset) = &To96($well_384, 'streak');

	my $pl_id = $self->GetPlId($well_96, $sec_id, $pt_id);
	return 0 if($pl_id eq '0');
	
#	my $result = $self -> InsertClonesPsesWell($clo_id, $new_pse_id, $pl_id);
	my $result = $self -> InsertDNAPSE($clo_id, $new_pse_id, $pl_id);
	return 0 if($result == 0);
	
    }
    
    return 1;

} #CloneTrans96To96


##########################################################
# Log a transfer from 96 to 96 subclone locations event #
##########################################################
sub CloneTrans96To96Update {
    
    my ($self, $barcode, $pre_pse_id, $new_pse_id) = @_;
    
    my $lol =  $self -> {'GetCloPlIdFromClonePse'} -> xSql($barcode, $pre_pse_id);
    return 0 if(! defined $lol->[0][0]);
    
    foreach my $row (@{$lol}) {
	my $clo_id = $row->[0];
	my $well_96 = $row->[1];
	my $pl_id = $row->[2];

	my $result = $self -> UpdateClonesPsesWell($clo_id, $new_pse_id, $pl_id);
	return 0 if($result == 0);
	
    }
    
    return 1;

} #CloneTrans96To96

##########################################################
# Log a transfer from 384 to 96 subclone locations event #
##########################################################
sub CloneTransGelToGel {
    
    my ($self, $barcode, $pre_pse_id, $new_pse_id) = @_;
    
    my $lol =  $self -> {'GetCloLaneFromClonePse'} -> xSql($barcode, $pre_pse_id);
    return 0 if(! defined $lol->[0][0]);
    
    foreach my $row (@{$lol}) {
	my $clo_id = $row->[0];
	my $lane = $row->[1];

#	my $result = $self -> InsertClonesPsesLane($clo_id, $new_pse_id, $lane);
	my $result = $self -> InsertDNAPSE($clo_id, $new_pse_id, $lane);
	return 0 if($result == 0);
	
    }
    
    return 1;

} #CloneTrans96To96

##########################################################
# Log a transfer from 384 to 96 subclone locations event #
##########################################################
sub CloneTrans96ToStreak {
    
    my ($self, $barcode, $pre_pse_id, $new_pse_id) = @_;
    
    $self->{'Error'} = "This function has not been setup, please contact informatics.";
    return 0;
    
    my $lol =  $self -> {'GetCloPlIdFromClonePse'} -> xSql($barcode, $pre_pse_id);
    return 0 if(! defined $lol->[0][0]);
    
    foreach my $row (@{$lol}) {
	my $clo_id = $row->[0];
	my $well_96 = $row->[1];
	my $pl_id = $row->[2];

	my ($well96, $streak_subset) = &ConvertWell::To96($well_96, 'streak');


	my $result = $self -> InsertClonesPsesLane($clo_id, $new_pse_id, $pl_id);
	return 0 if($result == 0);
	
    }
    
    return 1;

} #CloneTrans96ToStreak



############################################################
# Load the cycle plate and check enzyme schedule for clone #
############################################################
sub LoadCyclePlate2Enzymes {
    
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
    my $update_status = 'completed';
    my $update_result = 'successful';
    
    my $reagent_buffer = $options->{'Reagents'}->{'Enzyme Buffer'}->{'barcode'};
    my $reagent_enzyme1 = $options->{'Reagents'}->{'Enzyme 1'}->{'barcode'};
    my $reagent_enzyme2 = $options->{'Reagents'}->{'Enzyme 2'}->{'barcode'};
    
    my $buffer = $self -> GetEnzIdFromReagent($reagent_buffer);
    my $enzyme1 = $self -> GetEnzIdFromReagent($reagent_enzyme1);
    my $enzyme2 = $self -> GetEnzIdFromReagent($reagent_enzyme2);

    if(! $enzyme1 && $enzyme2) {
      $self->{'Error'} = "$pkg: " . ($enzyme1 ? "" : "$reagent_enzyme1") . ($enzyme1 || $enzyme2 ? "" : " and ") . ($enzyme2 ? "" : "$reagent_enzyme2") . " do NOT have the enzyme links!\n";
      return 0;
    }

    my $eps_id = $self->{'GetPsId'}->xSql("Digest", "schedule enzyme", "digest setup", "cycle plate", "mapping");
    my($pse_id) = $self->GetSchedEnzIdForBarcode($eps_id, $bars_in->[0], [$enzyme1->[0][0], $enzyme2->[0][0]], $buffer);

    #LSF: Check to see they have the common
    #if($pse_id1 != $pse_id2) {
    if(! $pse_id) {
      $self->{'Error'} = "ERROR: Cannot find scheduled $enzyme1->[0][0] and $enzyme2->[0][0] enzymes pse id\n";
      return 0;
    }

    #my $pse_id = $pse_id1;
 
    my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_ids->[0]);
    return 0 if($result == 0);

    unless ($pse_id == -1) {
	$result = $self -> Process('UpdatePse', 'completed', 'successful', $pse_id);
	return 0 if($result == 0);
    }

    my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_ids->[0], $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);

    $result = $self -> CloneTrans96To96($bars_in->[0], $pre_pse_ids->[0], $new_pse_id);
    return 0 if($result == 0);
    
    #$result = $self -> Process('InsertBarcodeEvent', $bars_in->[0], $new_pse_id, 'in');
    #return 0 if($result == 0);
    #$result = $self -> Process('InsertBarcodeEvent', $bars_out->[0], $new_pse_id, 'out');
    #return 0 if($result == 0);
    #$result = $self -> Process('UpdatePse', 'inprogress', '', $new_pse_id);
    #return 0 if($result == 0);

    #$result = $self -> CloneTrans96To96Update($bars_in->[0], $pre_pse_ids->[0], $new_pse_id);
    #return 0 if($result == 0);
    
    return [$new_pse_id];
} #LoadCyclePlate

############################################################
# Load the cycle plate and check enzyme schedule for clone #
############################################################
sub LoadCyclePlate {
    
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $update_status = 'completed';
    my $update_result = 'successful';
    
    my $reagent_buffer = $options->{'Reagents'}->{'Enzyme Buffer'}->{'barcode'};
    my $reagent_enzyme = $options->{'Reagents'}->{'Enzyme'}->{'barcode'};
    
    my $buffer = $self -> GetEnzIdFromReagent($reagent_buffer);
    my $enzyme = $self -> GetEnzIdFromReagent($reagent_enzyme);

    if(! $enzyme) {
      $self->{'Error'} = "$pkg: " . ($enzyme ? "" : "$reagent_enzyme") . " does NOT have the enzyme links!\n";
      return 0;
    }

    my $eps_id = $self->{'GetPsId'}->xSql("Digest", "schedule enzyme", "digest setup", "cycle plate", "mapping");
    
    #my ($pse_id) = $self -> GetSchedEnzIdForBarcode($eps_id, $bars_in->[0], $enzyme->[0][0], $buffer);
    my($pse_id) = $self->GetSchedEnzIdForBarcode($eps_id, $bars_in->[0], [$enzyme->[0][0]], $buffer);
    return 0 if(!$pse_id);
 
    my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_ids->[0]);
    return 0 if($result == 0);

    unless ($pse_id == -1) {
	$result = $self -> Process('UpdatePse', 'completed', 'successful', $pse_id);
	return 0 if($result == 0);
    }


    my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_ids->[0], $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);

    $result = $self -> CloneTrans96To96($bars_in->[0], $pre_pse_ids->[0], $new_pse_id);
    return 0 if($result == 0);
    
    #$result = $self -> Process('InsertBarcodeEvent', $bars_in->[0], $new_pse_id, 'in');
    #return 0 if($result == 0);
    #$result = $self -> Process('InsertBarcodeEvent', $bars_out->[0], $new_pse_id, 'out');
    #return 0 if($result == 0);
    #$result = $self -> Process('UpdatePse', 'inprogress', '', $new_pse_id);
    #return 0 if($result == 0);

    #$result = $self -> CloneTrans96To96Update($bars_in->[0], $pre_pse_ids->[0], $new_pse_id);
    #return 0 if($result == 0);
    
    return [$new_pse_id];
} #LoadCyclePlate



sub SetupGel {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

#LSF: Since this is check in CheckIfUsedGelPositionAsOutput function.  This is not necessary anymore.
=head1    
    my $top_desc = $self->{'EquipmentBarcodeDescription'} -> xSql($bars_out->[0]);
    my $bot_desc = $self->{'EquipmentBarcodeDescription'} -> xSql($bars_out->[1]);
    if($top_desc !~ /top$/i) {
	$self->{'Error'} = "Barcode $bars->[0] ($top_desc) is not top position!";
	return 0;    
    }
    if($bot_desc !~ /bottom$/i) {
 	$self->{'Error'} = "Barcode $bars->[0] ($bottom_desc) is not bottom position!";
	return 0;
    }
=cut
    #my $new_pse_id1 = $self -> BarcodeProcessEvent($ps_id, undef, [$bars_out->[0]], 'inprogress', '', $emp_id, 0);
    unless($pre_pse_ids && @$pre_pse_ids) {
      $pre_pse_ids = [0];
    }
    my $new_pse_id1 = $self -> EquipmentProcessEvent($ps_id, undef, [$bars_out->[0]], 'inprogress', '', $emp_id, 0, $pre_pse_ids);
    return ($self->GetCoreError) if(!$new_pse_id1);

    #my $new_pse_id2 = $self -> BarcodeProcessEvent($ps_id, undef, [$bars_out->[1]], 'inprogress', '', $emp_id, 0);
    my $new_pse_id2 = $self -> EquipmentProcessEvent($ps_id, undef, [$bars_out->[1]], 'inprogress', '', $emp_id, 0, $pre_pse_ids);
    return ($self->GetCoreError) if(!$new_pse_id2);
    
    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});

    my ($pso_id, $data, $lov) = $TouchSql -> GetPsoInfo($ps_id, 'Gel Position');
    if(!$pso_id) {
	$self->{'Error'} = $TouchScreen::TouchSql::Error;
	return 0;
    }

    my $result = $TouchSql -> InsertPsePsoInfo($new_pse_id1, $pso_id, 'top');
   
    $result = $TouchSql -> InsertPsePsoInfo($new_pse_id2, $pso_id, 'bottom');
    
    #$result = $self->AssignEquipment($bars_in->[0], 0, $new_pse_id1);
    #$result = $self->AssignEquipment($bars_in->[1], 0, $new_pse_id2);
    my %d = (
      $new_pse_id1 => $bars_in->[0],
      $new_pse_id2 => $bars_in->[1],
    );
    foreach my $tpse_id (keys %d) {
      my $result = $TouchSql -> EquipmentEvent($tpse_id, $d{$tpse_id});
      if(!$result) {
	  $self->{'Error'} = $TouchScreen::TouchSql::Error;
	  return 0;
      }
    }
       
    $TouchSql -> destroy;
    
    return [$new_pse_id1, $new_pse_id2];
}

sub EquipmentProcessEvent {

    my ($self, $ps_id, $bar_in, $bars_out, $status, $pse_result, $emp_id, $session, $pre_pse_ids) = @_;
    
    $session = 0 if(!defined $session);

    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});
    
    my $new_pse_id =  $self->Process('GetNextPse');
    return (0) if(!$new_pse_id);
    
    my $result = $self->Process('InsertPseEvent', $session, $status, $pse_result, $ps_id, $emp_id, $new_pse_id, $emp_id, 0, $pre_pse_ids->[0]);
    return (0) if(! defined $result);
    
    #bs_barcode, pse_pse_id, direction
    if(defined $bar_in) {
      $result = $TouchSql -> EquipmentEvent($new_pse_id, $bar_in);
      if(!$result) {
	  $self->{'Error'} = $TouchScreen::TouchSql::Error;
	  return 0;
      }
    }

    if(defined $bars_out->[0]) {
	foreach my $bar_out (@{$bars_out}) {
	  $result = $TouchSql -> EquipmentEvent($new_pse_id, $bar_out);
	  if(!$result) {
	      $self->{'Error'} = $TouchScreen::TouchSql::Error;
	      return 0;
	  }
	}
    }
    
    $result =  $self->Process('UpdatePse', $status, $pse_result, $new_pse_id);
    return 0 if(! defined $result);
 
    return $new_pse_id;
}

sub DigestGelLoading {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $empty = 0;

    my $gel_info = $self->{'GetAvailGelPsePosition'} -> xSql($bars_out->[0]);
    
    my $result;
    if($bars_in->[1] !~ /^empty/){
	$result = $self -> CloneTransferTo8ChannelGel($ps_id, [$bars_in->[1]], $bars_out, $emp_id, $options, $pre_pse_ids);
	return $result if(!$result);

	my $uresult = $self -> Process('UpdatePse', 'completed', 'successful', $gel_info->[0][0]);
	return 0 if($uresult == 0);
    }
    else {
	my $uresult = $self -> Process('UpdatePse', 'completed', 'successful', $gel_info->[0][0]);
	return 0 if($uresult == 0);
    }


    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});
    
    foreach my $pse_id (@$result) {
	    
	my $result = $TouchSql -> EquipmentEvent($pse_id, $bars_in->[0]);
	if(!$result) {
	    $self->{'Error'} = $TouchScreen::TouchSql::Error;
	    return 0;
	}
    }
    
    $TouchSql -> destroy;
    
    return $result;
}
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

sub MappingFailBarcode {

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
            my $result = $self -> Process('UpdatePse', 'completed', 'unsuccessful', $pse_id);
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
	pb.pse_pse_id = pse.pse_id
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

    my $update_status = 'inprogress';
    my $update_result = '';
    my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], [$bars_out->[1]], 'completed', 'successful', $emp_id, undef, $pses->[0]);
    return 0 if ($new_pse_id == 0);
    foreach my $pso_id (keys %{$data_options}) {
	my $info = $data_options -> {$pso_id};
	if(defined $info) {
	  if($$info !~ /^fail$|^abandone$|^terminate$/) {
	    $sql = "select ps_id from process_steps where pro_process = '" . $$info . "' and gro_group_name = 'mapping'";

	    my $tps_id= Query($dbh, $sql);
    	    my ($tnew_pse_id) = $self -> xOneToManyProcess($tps_id, $new_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    	    my $result = $self -> CloneTrans96To96($bars_in->[0], $pses->[0], $tnew_pse_id);
	    return 0 if(! $result);
	    return [$tnew_pse_id];
	  }
	}
    }
    return [$new_pse_id];
} #FailBarcode


sub DigestGelStaining {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    
    my $result = $self -> CloneTransferGel($ps_id, $bars_in, [], $emp_id, $options, $pre_pse_ids);
    return $result if(!$result);
    
    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});
     foreach my $pse_id (@$result) {
	    
	my $result = $TouchSql -> EquipmentEvent($pse_id, $bars_out->[0]);
	if(!$result) {
	    $self->{'Error'} = $TouchScreen::TouchSql::Error;
	    return 0;
	}
    }
    
    $TouchSql -> destroy;
    
    return $result;
} #DigestGelStaining

sub DigestGelToScanPlate {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    #LSF: Find the digest gel barcode
    #select * from pse_equipment_informations pei, pse_barcodes pb where pei.pse_pse_id = pb.pse_pse_id and equinf_bs_barcode = ?
    my $lol = $self->{'GetCloneFromEquipment'}->xSql($bars_in->[0]);
=cut
    my @pses = GSC::PSE->get(sql => [qq/select pse.* from pse_equipment_informations pei, process_step_executions pse
    where pei.pse_pse_id = pse.pse_id and pse.psesta_pse_status = 'inprogress' and pei.equinf_bs_barcode = ?/, $bars_in->[0]]);
    my @pbs = GSC::PSEBarcode->get(pse_id => \@pses);
    unless(@pbs) {
      $self->{'Error'} = "Could not find gel barcode for equipment $bars_in->[0].";
      return 0;    
    }
=cut
    if(! defined $lol->[0][0]) {
      $self->{'Error'} = "Could not find gel barcode for equipment $bars_in->[0].";
      return 0;
    }
    #my $result = $self -> CloneTransferGel($ps_id, $bars_in, [], $emp_id, $options, $pre_pse_ids);
    my $result = $self -> CloneTransferGel($ps_id, [$lol->[0][0]], [], $emp_id, $options, $pre_pse_ids);
=cut
    my $result = $self -> CloneTransferGel($ps_id, [$pbs[0]->barcode], [], $emp_id, $options, $pre_pse_ids);
=cut
    return $result if(!$result);
    
    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});
     foreach my $pse_id (@$result) {
	    
	my $result = $TouchSql -> EquipmentEvent($pse_id, $bars_out->[0]);
	if(!$result) {
	    $self->{'Error'} = $TouchScreen::TouchSql::Error;
	    return 0;
	}
    }
    
    $TouchSql -> destroy;
    
    return $result;
} #DigestGelToScanPlate

sub ScanImage {
  

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;

    my $sinfo = $self->{'GetStainGelBarcodePse'} -> xSql($bars_in->[0]);
    
    my $result = $self -> CloneTransferGel($ps_id, [$sinfo->[0][0]], [], $emp_id, $options, [$sinfo->[0][1]]);
    return $result if(!$result);
    
    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});
    foreach my $pse_id (@$result) {
	
	my $result = $TouchSql -> EquipmentEvent($pse_id, $bars_in->[0]);
	if(!$result) {
	    $self->{'Error'} = $TouchScreen::TouchSql::Error;
	    return 0;
	}
    }
    
    $TouchSql -> destroy;
    
    return $result;


}

sub CloneTransferTo8ChannelGel {

    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options, $pre_pse_ids) = @_;
 
    my $update_status = 'completed';
    my $update_result = 'successful';
    
    my $pre_pse_id = $pre_pse_ids->[0];
    if(! defined $pre_pse_id) {
	$self -> {'Error'} = "Could not find a valid pre_pse_id.";
    }
    
    my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], $bars_out, $emp_id);
    
 
    my $result = $self -> CloneTrans96ToGel($bars_in->[0], $pre_pse_id, $new_pse_id);
    return 0 if($result == 0);
    
    return [$new_pse_id];


} #CloneTransferTo8ChannelGel


##########################################################
# Log a transfer from 384 to 96 subclone locations event #
##########################################################
sub CloneTrans96ToGel {
    
    my ($self, $barcode, $pre_pse_id, $new_pse_id) = @_;
    
    my $lol =  $self -> {'GetCloPlIdFromClonePse'} -> xSql($barcode, $pre_pse_id);
    return 0 if(! defined $lol->[0][0]);
    
    foreach my $row (@{$lol}) {
	my $clo_id = $row->[0];
	my $well_96 = $row->[1];
	my $pl_id = $row->[2];

	my $lane = &ConvertWell::ToGel($well_96, 8);
        my $dl_id = $self->GetDlId($lane, 'gel lane');
	return 0 if(! $dl_id);
#	my $result = $self -> InsertClonesPsesLane($clo_id, $new_pse_id, $lane);
	my $result = $self -> InsertDNAPSE($clo_id, $new_pse_id, $dl_id);
	return 0 if($result == 0);
	
    }
    
    return 1;

} #CloneTrans96To96


##########################################
# Insert fra_id into clones_pses #
##########################################
sub UpdateClonesPsesWell{
    
    my ($self, $clo_id, $new_pse_id, $pl_id) = @_;
    
#    my $result =  $self ->{'UpdateClonesPsesWell'}->xSql($pl_id, $clo_id, $new_pse_id);

    my $result = GSC::DNAPSE->get(dna_id => $clo_id, pse_id => $new_pse_id) -> set(dl_id => $pl_id);
    if($result) {
	return $result;
    }
    
    $self->{'Error'} = "$pkg: InsertClonesPses() -> $clo_id, $new_pse_id, $pl_id";

    return 0;
} #InsertClonesPses


##########################################
# Insert fra_id into clones_pses #
##########################################
#sub InsertClonesPsesWell{
#   
#   my ($self, $clo_id, $new_pse_id, $pl_id) = @_;
#   
#   my $result =  $self ->{'InsertClonesPsesWell'}->xSql($clo_id, $new_pse_id, $pl_id);
#   if($result) {
#	return $result;
#   }
#   
#   $self->{'Error'} = "$pkg: InsertClonesPses() -> $clo_id, $new_pse_id, $pl_id";
#
#   return 0;
#} #InsertClonesPses
 
##########################################
# Insert fra_id into clones_pses #
##########################################
#sub InsertClonesPsesLane{
#    
#    my ($self, $clo_id, $new_pse_id, $lane_id) = @_;
#    
#    my $result =  $self ->{'InsertClonesPsesLane'}->xSql($clo_id, $new_pse_id, $lane_id);
#    if($result) {
#	return $result;
#    }
#    
#    $self->{'Error'} = "$pkg: InsertClonesPses() -> $clo_id, $new_pse_id, $lane_id";
#
#    return 0;
#} #InsertClonesPses
 


############################################################
# Get the Available quadrants for a 384 plate to inoculate #
############################################################
sub GetAvailableQuadsPses {

    my ($self, $barcode) = @_;
    
    my $lol = $self->{'GetAvailableQuadsPses'} -> xSql($barcode);
   
    if(defined $lol->[0][0]) {
	return $lol;
    }

    $self -> {'Error'} = "$pkg: GetAvailableQuadsPses() -> Could not find available quadrants.";
    return 0;

} #GetAvailableQuadsPses


sub GetAvailableQuadsPsesIn {

    my ($self, $barcode, $wellcount) = @_;
    
    my $lol = $self->{'GetAvailableQuadsPsesIn'} -> xSql($barcode,$wellcount);
   
    if(defined $lol->[0][0]) {
	return $lol;
    }

    $self -> {'Error'} = "$pkg: GetAvailableQuadsPsesIn() -> Could not find available quadrants.";
    return 0;

} #GetAvailableQuadsPsesIn



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

####################################################
# Get the plate id from the well, sec_id and pt_id #
####################################################
sub GetDlId {

    my ($self, $well, $type) = @_;
    my $pl_id = $self->{'GetDlId'} ->xSql($well, $type);
    if(defined $pl_id) {
	return $pl_id;
    }
    
    $self->{'Error'} = "$pkg: GetDlId() -> Could not find pl_id where $well, $type.";
    return 0;
} #GetPlId


#################################
# Get the enz_id from a barcode #
#################################
sub GetEnzIdFromReagent {

    my ($self, $reagent_barcode) = @_;
    
    my $enz_id = $self -> {'GetEnzIdFromReagent'} -> xSql($reagent_barcode);

    if($enz_id && $enz_id->[0][0]) {
	return $enz_id;

    }

    $self -> {'Error'} = "$pkg: GetEnzIdFromReagent() -> Could not get enz_id for reagent barcode = $reagent_barcode.";
    return 0;
} #GetEnzIdFromReagent

#############################################
# Get the scheduled enz_id for these clones #
#############################################
sub GetSchedEnzIdForBarcode {

    my ($self, $ps_id, $barcode, $enz_ids, $b_enz_id) = @_;
    
    my %benz;
    #It can be more than one buffer enz_id
    foreach my $r (@$b_enz_id) {
      $benz{$r->[0]} = 1;
    }
    
    #It can be more than one enz_ids
    my %enz;
    foreach my $r (@$enz_ids) {
      $enz{$r} = 1;
    }

    my @dp = GSC::DNAPSE->get(pse_id=>[map {$_->pse_id} GSC::PSEBarcode->get(barcode=>$barcode)]);
    my $clo = GSC::DNA->get($dp[0]->dna_id);
    my $clo_dr = $clo->get_dna_resource();
    my $clo_dr_pse = $clo_dr->get_creation_event();
    my $ptd = GSC::ProcessingTypeDirective->get(pse_id=>$clo_dr_pse->pse_id,
						general_type_name=>'mapping digest enzyme ids');
    
    my $clone_info = $self -> {'GetScheduledEnzPseFromProcessBarcode'} -> xSql($ps_id, $barcode);
    my @pse_ids;
    my %rr;
    if(! defined $clone_info->[0][0] && !defined $ptd) {


      $self -> {'Error'} = "$pkg: GetSchedEnzIdForBarcode() -> Could not find enz_id and pse_id for barcode = $barcode.";
      return;
    }
    
    foreach my $data (@$clone_info) {
      my $enz_id = $data->[0];
      my $pse_id = $data->[1];
      $rr{$pse_id}->{$enz_id} = $enz{$enz_id};
    }

    # do the same with a fake PSE id
    if ($ptd) {
	my @ptd_enz_ids = split /,/, $ptd->specific_type_name;
	foreach my $enz_id (@ptd_enz_ids) {
	    $rr{-1}->{$enz_id} = $enz{$enz_id};
	}
    }

    
    
    # sort in reverse to ensure we catch pses that are scheduled
    # and return those first so they can be completed 
    # before looking to the catch-all, since the 
    # catchall scheduled enzyme is mapped into "pse id" -1 here
    foreach my $pse_id (sort {$b<=>$a} keys %rr) {
      my $gnext = 0;
      my $count = 0;
      foreach my $enz_id (keys %{$rr{$pse_id}}) {
        if(! $rr{$pse_id}->{$enz_id}) {
	  $gnext = 1;
	  last;
	}
	$count ++;
      }
      next if($gnext);
      next if($count != scalar @$enz_ids);
      return ($pse_id);
    }
    
    my $escan  = join ", ", map { $_->enzyme_name } GSC::Enzyme->get(enz_id => $enz_ids);
    my $bscan  = join ", ", map { $_->enzyme_name } GSC::Enzyme->get(enz_id => [map { $_->[0] } @$b_enz_id]);

    $self->{'Error'} = "$pkg: LoadCyclePlate() -> Scheduled Enzyme: Do not match scanned Reagent Enyme: $escan and Buffer: $bscan.";
    return 0;

} #GetSchedEnzIdForBarcode

sub LogActiveReagentLoadDye {

    my ($self, $pses) = @_;

    my $result = $self -> LogActiveReagent($pses, 'Orange G Loading Dye');

    return $result;
}

sub LogActiveReagentGelBuffer {

    my ($self, $pses) = @_;

    my $result = $self -> LogActiveBuffer($pses);

    return $result;
}

sub LogActiveReagentBufferMarker {

    my ($self, $pses) = @_;

    my $result = $self -> LogActiveBuffer($pses);
    return $result if(!$result);

    return $result;
}

sub LogActiveReagentStainBuffer {

    my ($self, $pses) = @_;

    my $result = $self -> LogActiveBuffer($pses);
    if(! $result) {
      $self -> {'Error'} = "$pkg: LogActiveReagentStainBuffer -> There is no active buffer for pse id $pses->[0]!";
      return $result;
    }
    $result = $self -> LogActiveReagent($pses, 'SYBR Green Dye');

    return $result;
}



sub LogActiveReagent {

    my ($self, $pses, $reagent) = @_;

    my $barcode = $self -> GetActiveReagentBarcode($reagent);

    return 0 if(!$barcode);

    my $result = $self -> LogActiveReagentEvent($barcode, $pses);

    return 0 if(!$result);

    return 1;
}

sub LogActiveBuffer { 
    my ($self, $pses) = @_;
    my @pses = GSC::PSE->get(pse_status => "inprogress", ps_id => [GSC::ProcessStep->get(process_to => "dilute buffer")]); 
    my @pbs = GSC::PSEBarcode->get(pse_id => \@pses, direction => 'in');    
    return unless(@pbs);
    return $self->LogActiveReagentEvent($pbs[0]->barcode, $pses) ? 1 : 0;
}

sub GetActiveReagentBarcode {
    my ($self, $reagent) = @_;
    my @ris = GSC::ReagentInformation->get(reagent_name => $reagent, status => 'available');
    return @ris[0]->barcode if(@ris == 1);
    $self->{'Error'} = "$pkg: GetActiveReagentBarcode() -> " . ( @ris > 1 ? "More than one active batch for " : "Could not find active reagent for ")  . $reagent;     
    return 0;
}

sub LogActiveReagentEvent {


    my ($self, $barcode, $pses) = @_;

    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});
    

    foreach my $pse_id (@$pses) {
	    
	my $result = $TouchSql -> ReagentEvent($pse_id, $barcode);
	if(!$result) {
	    $self->{'Error'} = $TouchScreen::TouchSql::Error;
	    return 0;
	}
    }
    
    $TouchSql -> destroy;

    return 1;
}
sub GenerateFileName {

    my ($self, $ps_id, $desc, $barcode) = @_;

    
    my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});

    my ($pso_id, $data, $lov) = $TouchSql -> GetPsoInfo($ps_id, $desc);
    
    $TouchSql -> destroy;

    my ($year, $month, $day) = Today();
  
    my $lol = LoLquery($self->{'dbh'},  qq/select distinct clone_name, sector_name  from 
			       plate_locations, sectors,
			       process_step_executions pse, process_steps,
			       clones_pses cx,
			       clones
			       where 
			       clo_clo_id = clo_id and
			       pl_id = pl_pl_id and
			       sec_id = sec_sec_id and
			       pse.pse_id = cx.pse_pse_id and 
			       ps_ps_id = ps_id and
			       pro_process_to like 'schedule%' and
			       purpose = 'Clone Receiving' and
			       clo_id in (select clo_clo_id from clones_pses, pse_equipment_informations, process_steps, process_step_executions
					  where 
					  ps_id = ps_ps_id and
					  clones_pses.pse_pse_id = pse_id and
					  pse_id = pse_equipment_informations.pse_pse_id and
					  psesta_pse_status = 'inprogress' and
					  pro_process_to = 'digest gel staining' and
					  purpose = 'Run Digest Gel' and
					  equinf_bs_barcode = '$barcode->[0]')/, 'ListOfList');
    
    
    
    
    if(defined $lol->[0][0]) {
	
	my $lib = substr($lol->[0][0], 0, length($lol->[0][0]) - 3);
	$data = $lib.'_'.$lol->[0][1].'_'.$year.$month.$day;
	
    }

    return ($pso_id, $data, $lov);
} #GenerateFileName

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

    my $lol = $self->{'GetBarcodeCloneGrowthPlWellPse'} -> xSql('in', $bars_in->[0], 'inprogress', 'spin down beckman block');
    foreach my $pre_pse_id (@{$pre_pse_ids}) {
	
	my $result = $self -> Process('UpdatePse', 'completed', 'successful', $pre_pse_id);
	return 0 if($result == 0);
	
    }
	
    my $new_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'inprogress', '', $emp_id, undef, $pre_pse_ids->[0]);
    return ($self->GetCoreError) if(!$new_pse_id);

    my $fail_pse_id;
    if(@no_grows) {
	
	$fail_pse_id = $self -> BarcodeProcessEvent($ps_id, $bars_in->[0], $bars_out, 'abandoned', 'terminated', $emp_id, undef, $pre_pse_ids->[0]);
	return ($self->GetCoreError) if(!$fail_pse_id);
	
    }

    foreach my $row (@{$lol}) {
	
	my @inlist = grep(/^$row->[2]$/, @no_grows);
	my $result;
	if(! @inlist) {

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

sub GetAvailVerifyGrowths{

    my ($self, $barcode, $ps_id) = @_;


    my ($result, $pses) = $self -> GetAvailClonePf($barcode, $ps_id, 'scheduled', 'in', 'Clone Setup');

    if(!$result) {
	($result, $pses) = $self -> GetAvailClonePf($barcode, $ps_id, 'inprogress', 'in', 'Clone Setup');
	#LSF: Get rid of the barcode in the description since the main program will append the barcode for it.
	#$result =~ s/^$barcode//;
	return ($result, $pses);
    }
    
    $self -> {'Error'} = "$pkg: GetAvailVerifyGrowths() -> There are still inputs plates scheduled for this plate = $barcode";
    
    #LSF: Get rid of the barcode in the description since the main program will append the barcode for it.
    #$result =~ s/^$barcode//;
    return ($result);
}

=head2 GetBarcodePSES

Get all the pses the status specified for a barcode.

@return pses

=cut

sub GetBarcodePSES {

    my ($self, $barcode, $status) = @_;
    my @pses;
    $status = $status ? $status : 'inprogress';
    my $lol = $self -> {'GetBarcodeEquipmentPSES'} ->xSql($status, $barcode);
    if($lol) {
      foreach (@$lol) {
        push @pses, $_->[0];
      }
    }
    $lol = $self -> {'GetBarcodeDNAPSES'} ->xSql($status, $barcode);
    if($lol) {
      foreach (@$lol) {
        push @pses, $_->[0];
      }
    }
    my %unique = map { $_ => 1 } @pses;
    return [keys %unique];
}
#################################
# get archive in subclones pses #
#################################
sub GetAvailClonePf {

    my ($self, $barcode, $ps_id, $status, $direction, $purpose) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
						
    my $lol = $self -> {'GetAvailClonePf'} ->xSql($status, $barcode, $direction, $ps_id, $purpose);
    
    if(defined $lol->[0]) {
	my $pses = [];
	for my $i (0 .. $#{$lol}) {
	    push(@{$pses}, $lol->[$i]);
	}
	
        my $TouchSql = TouchScreen::TouchSql->new($self->{'dbh'}, $self->{'Schema'});
	my @data = $TouchSql->GetBarcodeDesc($barcode);
	my $desc = $data[1]->[0]->[0];
	if(! $data[0]) {
	  $desc=$self->{'GetBarcodeDesc'} ->xSql($barcode);
	}
	return ($desc, $pses);
    }
	
    $self->{'Error'} = "$pkg: GetAvailClonePf() -> Could not find barcode description information for barcode = $barcode, ps_id = $ps_id, status = $status.";
    
	
    return 0;

} #GetAvailClonePf

=head1 getCloneGrowthLibDescription

=cut
sub getCloneGrowthLibDescription {
  my($self, $lol) = @_;
  foreach my $info (@$lol) {
    if($info->[0] !~ /\s+unknown|\s+none/i) {
      return $info->[0];
    } 
  }
  return $lol->[0][0];
}

sub GetAvailClaimBarcode { # this replaced getavailclaiminprogress
    my ($self, $barcode, $ps_id) = @_;
    
    return $self->GetAvailBarcodeOutInprogress($barcode, $ps_id);
}

sub GetAvailBarcodeInInprogress {
    my ($self, $barcode, $ps_id) = @_;
    
    return $self->GetAvailBarcodeInInprogress($barcode, $ps_id);
}

sub ClaimBarcodeBySector {
    #- this procedure, by kevin, takes in standard information for a *container* that has sectors 
    #  and a single pse for the entire container,
    #  and executes the next step for each sector, linking the dna appropriately
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;

    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i = 0;

    #- this gets the soon-to-be-previous step and assumes there is only one pse (following another person's form)
    #  should this check if there is more than one?  Perhaps.
    my ($lib, $ref_pses) = $self->GetAvailBarcodeOutInprogress($bars_in->[0], $ps_id);
    my $pre_pse_id = $ref_pses->[0];
    
    #- this gets all dna, right away, that are mapped to it
    my @dps = GSC::DNAPSE->get(pse_id => $pre_pse_id);
    unless(@dps){
	$self->{'Error'} = "No DNA-PSEs for barcode $bars_in->[0]";
	return 0;
    }
    
    # we get the location type for this type of dna, then get all locations for that location type grouped by sector
    #    as we want a pse per sector, this is appropriate
    my ($loctype) = App::DB->dbh->selectrow_array(qq/select location_type from dna_location where dl_id = ?/, undef, $dps[0]->dl_id);
    my %dls = map {$_->dl_id => $_} GSC::DNALocation->get(location_type => $loctype);
    
    # we now look at every dna.  as we want to create some number of pses that uses all and no more than the dna for the last step,
    #    this is the most concise way to loop
    my %newpses;
    foreach my $dp (@dps){
	#get the location
	my $dl = $dls{$dp->dl_id};
	#create the pse for this sector, if it doesn't exist
	unless(exists $newpses{$dl->sec_id}){
	    $newpses{$dl->sec_id} = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [], $emp_id);
	}

	#link the dna to the appropriate pse
	my $dpc = GSC::DNAPSE->create(dna_id=>$dp->dna_id,
				      pse_id=>$newpses{$dl->sec_id},
				      dl_id=>$dp->dl_id);
	
	#set the clone status to mapping
	my $clo = GSC::Clone->get(clo_id => $dp->dna_id);
        unless($clo) {
            #maybe it is a clone growth
            my $cg = GSC::CloneGrowth->get(cg_id => $dp->dna_id);
            unless($cg) {
                $self->{'Error'} = 'The dna is not a clone or clone growth.';
                return 0;
            }

            $clo = GSC::Clone->get(clo_id => $cg->clo_id);
                 
        }
	if ($clo->clone_status ne "active") {
		$clo->clone_status('mapping');
	}

	if (!defined $dpc) {
	    $self->{'Error'} = "Unable to create dnapse";
	    return 0;
	}
    }
    
    #return the new pses
    return [values %newpses];
}

sub Claim384OnePseToFour {
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;

    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i = 0;

    my ($lib, $ref_pses) = $self->GetAvailBarcodeOutInprogress($bars_in->[0], $ps_id);
    
    my $pre_pse_id = $ref_pses->[0];
    
    foreach my $sector ('a1','a2','b1','b2') {
		    
	my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [], $emp_id);
	
	my @dp = GSC::DNAPSE->get(sql=>qq/SELECT dp.* FROM dna_pse dp
				  JOIN dna_location dl ON dl.dl_id = dp.dl_id
				  JOIN sectors sec on dl.sec_id = sec.sec_id
				  WHERE 
				  pse_id = $pre_pse_id AND sector_name = '$sector'/);
	
	foreach my $dp_prev (@dp) {
	    my $dpc = GSC::DNAPSE->create(dna_id=>$dp_prev->dna_id,
				pse_id=>$new_pse_id,
				dl_id=>$dp_prev->dl_id);
				    
            my $clo = GSC::Clone->get(clo_id => $dp_prev->dna_id);
	    if ($clo->clone_status() ne "active") {
	            $clo->clone_status('mapping');
	    }
	
	    if (!defined $dpc) {
		$self->{'Error'} = "Unable to create dnapse";
		return 0;
	    }
	}
	push(@{$pse_ids}, $new_pse_id);

    }
    
    return $pse_ids;
}

sub Claim384OnePseToFour_archive {
    my ($self, $ps_id, $bars_in, $bars_out, $emp_id, $options) = @_;

    my $pse_ids = [];
    my $update_status = 'completed';
    my $update_result = 'successful';
    my $i = 0;

    my ($lib, $ref_pses) = $self->GetAvailBarcodeInInprogress($bars_in->[0], $ps_id);
    
    foreach my $pre_pse_id (@$ref_pses) {
    
    #my $pre_pse_id = $ref_pses->[0];
    
    #foreach my $sector ('a1','a2','b1','b2') {
		    
	my ($new_pse_id) = $self -> xOneToManyProcess($ps_id, $pre_pse_id, $update_status, $update_result, $bars_in->[0], [], $emp_id);
	
	my @dp = GSC::DNAPSE->get(sql=>qq/SELECT dp.* FROM dna_pse dp
				  JOIN dna_location dl ON dl.dl_id = dp.dl_id
				  JOIN sectors sec on dl.sec_id = sec.sec_id
				  WHERE 
				  pse_id = $pre_pse_id/);
	
	foreach my $dp_prev (@dp) {
	    my $dpc = GSC::DNAPSE->create(dna_id=>$dp_prev->dna_id,
				pse_id=>$new_pse_id,
				dl_id=>$dp_prev->dl_id);
				    
            my $clo = GSC::Clone->get(clo_id => $dp_prev->dna_id);
	    if ($clo->clone_status() ne "active") {
            	$clo->clone_status('mapping');
	    }

	    if (!defined $dpc) {
		$self->{'Error'} = "Unable to create dnapse";
		return 0;
	    }
	}
	push(@{$pse_ids}, $new_pse_id);

    #}
    }
    return $pse_ids;
}

#-----------------------------------
# Set emacs perl mode for this file
#
# Local Variables:
# mode:perl
# End:
#
#-----------------------------------
