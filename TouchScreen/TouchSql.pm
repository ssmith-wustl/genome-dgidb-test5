# -*-Perl-*-

##############################################
# Copyright (C) 2001 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

package TouchScreen::TouchSql;

use strict;
use DBI;
use DbAss;
use TouchScreen::CoreSql;

#############################################################
# Production sql code package
#############################################################

require Exporter;

our $Error = '';

our @ISA = qw (Exporter AutoLoader);
our @EXPORT = qw ( );

my $pkg = __PACKAGE__;
our $SINGLETON;
#########################################################
# Create a new instance of the TouchSql code so that you #
# can easily use more than one data base schema         #
#########################################################
sub new {

    # Input
    my ($class, $dbh, $schema) = @_;
    #LSF: Assume you will not miss production and development database together. (I do not think this will happen).
    return $SINGLETON if($SINGLETON);
    my $self;

    $self = {};
    bless $self, $class;

    $self->{'dbh'} = $dbh;
    $self->{'Schema'} = $schema;
    
    $self->{'GetBarcodeDesc'} = LoadSql($dbh,"select barcode_description from barcode_sources where barcode = ?", 'Single');
    $self->{'GetUnixLogin'} = LoadSql($dbh,"select UNIX_LOGIN from GSC_USERS where gu_id = (select distinct gu_id from EMPLOYEE_INFOS where EI_ID = ?)", 'Single');
    $self->{'GetEmployeeInfo'} = LoadSql($dbh,"select GU_ID, UNIX_LOGIN from GSC_USERS where BS_BARCODE = ? and us_user_status = 'active'", 'ListOfList');
    $self->{'GetBarcodeFromUseId'} = LoadSql($dbh,"select BS_BARCODE from GSC_USERS where GU_ID = ? and us_user_status = 'active'", 'Single');
   
    $self->{'GetUserGroups'} = LoadSql($dbh,"select distinct GRO_GROUP_NAME from EMPLOYEE_INFOS where GU_GU_ID = ?
               and US_USER_STATUS = 'active'", 'List');

    $self->{'GetEmployeeId'} = LoadSql($dbh,"select EI_ID from EMPLOYEE_INFOS where GU_GU_ID = ? and GRO_GROUP_NAME = ? 
               and US_USER_STATUS = 'active'", 'Single');

    $self->{'GetGroupPurposes'} = LoadSql($dbh,"select distinct PURPOSE from PROCESS_STEPS where  PSS_PROCESS_STEP_STATUS = 'active' and 
               GRO_GROUP_NAME = ? and (BARCODE_INPUT_STATUS = 'yes' or BARCODE_OUTPUT_STATUS = 'yes')", 'List');
    $self->{'CheckIfBoss'} = LoadSql($dbh,"select count(*) from bosses where gu_gu_id_boss = ?", 'Single');
    $self->{'GetProcesses'} = LoadSql($dbh,"select distinct PRO_PROCESS_TO, Purpose_order, ps_id from PROCESS_STEPS
               where PSS_PROCESS_STEP_STATUS = 'active' and GRO_GROUP_NAME = ? 
               and (BARCODE_INPUT_STATUS = 'yes' or BARCODE_OUTPUT_STATUS = 'yes' or  
               MANUAL_CONFIRMATION = 'yes') and PURPOSE = ? order by PURPOSE_ORDER", 'ListOfList');

    $self->{'CountProcessEmps'} = LoadSql($dbh,"select count(*) from process_step_emp_infos where ps_ps_id = ?", 'Single');
    $self->{'CountMatchProcessEmps'} = LoadSql($dbh,"select count(*) from process_step_emp_infos where ps_ps_id = ? and ei_ei_id = ?", 'Single');

    $self->{'GetInputDevices'} = LoadSql($dbh,"select distinct OUTPUT_DEVICE from PROCESS_STEPS where 
               PSS_PROCESS_STEP_STATUS = 'active' and bp_barcode_prefix not in('00', '0j') and bp_barcode_prefix in 
               (select distinct bp_barcode_prefix_input from process_steps where PSS_PROCESS_STEP_STATUS = 'active' 
               and PRO_PROCESS_TO = ? and GRO_GROUP_NAME = ? and ((BARCODE_INPUT_STATUS = 'no' 
               and BARCODE_OUTPUT_STATUS = 'yes') or (BARCODE_INPUT_STATUS = 'yes' and BARCODE_OUTPUT_STATUS = 'no') 
               or (BARCODE_INPUT_STATUS = 'yes' and BARCODE_OUTPUT_STATUS = 'yes') or MANUAL_CONFIRMATION = 'yes') and PURPOSE = ?)", 'List');

    $self->{'GetOutputDevices'} = LoadSql($dbh,"select distinct OUTPUT_DEVICE, ps_id from PROCESS_STEPS where PSS_PROCESS_STEP_STATUS = 'active' 
               and PRO_PROCESS_TO = ? and GRO_GROUP_NAME = ? and ((BARCODE_INPUT_STATUS = 'no' 
               and BARCODE_OUTPUT_STATUS = 'yes') or (BARCODE_INPUT_STATUS = 'yes' and BARCODE_OUTPUT_STATUS = 'no') 
               or (BARCODE_INPUT_STATUS = 'yes' and BARCODE_OUTPUT_STATUS = 'yes') or MANUAL_CONFIRMATION = 'yes') and PURPOSE = ?", 'ListOfList');
    $self->{'GetOutputDevicesFromInput'} = LoadSql($dbh,"select distinct OUTPUT_DEVICE, ps_id from PROCESS_STEPS where PSS_PROCESS_STEP_STATUS = 'active' 
               and PRO_PROCESS_TO = ? and GRO_GROUP_NAME = ? and ((BARCODE_INPUT_STATUS = 'no' 
               and BARCODE_OUTPUT_STATUS = 'yes') or (BARCODE_INPUT_STATUS = 'yes' and BARCODE_OUTPUT_STATUS = 'no') 
               or (BARCODE_INPUT_STATUS = 'yes' and BARCODE_OUTPUT_STATUS = 'yes') or MANUAL_CONFIRMATION = 'yes') and PURPOSE = ? and bp_barcode_prefix_input in 
               (select bp_barcode_prefix from process_steps where output_device = ?)", 'ListOfList');

    $self->{'GetProcessInfo'} = LoadSql($dbh,"select BP_BARCODE_PREFIX, BP_BARCODE_PREFIX_INPUT, PS_ID 
               from PROCESS_STEPS where PSS_PROCESS_STEP_STATUS = 'active' and 
               PRO_PROCESS_TO = ? and GRO_GROUP_NAME = ? and ((BARCODE_INPUT_STATUS = 'no' 
               and BARCODE_OUTPUT_STATUS = 'yes') or (BARCODE_INPUT_STATUS = 'yes' or BARCODE_OUTPUT_STATUS = 'no') 
               or (BARCODE_INPUT_STATUS = 'yes' or BARCODE_OUTPUT_STATUS = 'yes')) and PURPOSE = ? 
               and OUTPUT_DEVICE = ?", 'ListOfList');
    $self->{'GetProcessInfoWithInput'} = LoadSql($dbh,"select BP_BARCODE_PREFIX, BP_BARCODE_PREFIX_INPUT, PS_ID 
               from PROCESS_STEPS where PSS_PROCESS_STEP_STATUS = 'active' and 
               PRO_PROCESS_TO = ? and GRO_GROUP_NAME = ? and ((BARCODE_INPUT_STATUS = 'no' 
               and BARCODE_OUTPUT_STATUS = 'yes') or (BARCODE_INPUT_STATUS = 'yes' or BARCODE_OUTPUT_STATUS = 'no') 
               or (BARCODE_INPUT_STATUS = 'yes' or BARCODE_OUTPUT_STATUS = 'yes')) and PURPOSE = ? 
               and OUTPUT_DEVICE = ? and pro_process in (select pro_process_to from process_steps where bp_barcode_prefix_input = ? or  bp_barcode_prefix = ?)", 'ListOfList');
    $self->{'GetUserSchedForPrinting'} = LoadSql($dbh,"select bs_barcode, rn_reagent_name, batch_number, container_count_stock 
               from reagent_informations where consta_status = 'scheduled' and pse_pse_id in 
               (select pse_id from process_step_executions where ei_ei_id = ? and ps_ps_id in 
               (select ps_id from process_steps where pro_process_to = 'make reagent'))", 'ListOfList');  
    $self->{'GetBarcodePrefix'} = LoadSql($dbh,"select distinct bp_barcode_prefix from process_steps where ps_id = ?", 'Single');  
    $self->{'GetProcessBarcodeLabel'} = LoadSql($dbh,"select lable from barcode_outputs where ps_ps_id = ?", 'Single');  
    $self->{'GetPsoId'} = LoadSql($dbh,"select PSO_ID from PROCESS_STEP_OUTPUTS where PS_PS_ID = ? and OUTPUT_DESCRIPTION = ?", 'Single');  

    $self->{'GetPsoInfo'} = LoadSql($dbh,"select DATA_VALUE, DEFAULT_FLAG from PSO_LIST_OF_VALUES where PSO_PSO_ID = ?", 'ListOfList');  
    $self->{'CountBarcodeUse'} = LoadSql($dbh,"select count(*) from pse_barcodes where bs_barcode = ? and direction = ?", 'Single');  

    $self->{'GetReageants'} = LoadSql($dbh,"select rn_reagent_name from process_step_reagents where ps_ps_id = ?", 'List');  
    $self->{'GetReagentPurposes'} = LoadSql($dbh,"select distinct rp_reagent_purpose from process_step_reagents where ps_ps_id = ?", 'List');  
    $self->{'CheckReagentBarcode'} = LoadSql($dbh,"select rn_reagent_name from reagent_informations where bs_barcode = ?", 'Single');  

    $self->{'GetReagentPurpose'} = LoadSql($dbh, qq/select rp_reagent_purpose, ri.rn_reagent_name, batch_number from process_step_reagents ps, 
					       reagent_informations ri where ps_ps_id = ? and
					       ri.rn_reagent_name = ps. rn_reagent_name and
					       bs_barcode = ?/, 'ListOfList');

    $self->{'GetMachines'} = LoadSql($dbh,"select bs_barcode, machine_number from equipment_informations where bs_barcode in 
               (select equinf_bs_barcode from process_steps_equipments where ps_ps_id = ?) order by machine_number", 'List');  
    
    $self->{'GetMachineInfo'} = LoadSql($dbh,"select equ_equipment_description, machine_number from equipment_informations 
                                                 where bs_barcode = ?", 'ListOfList');  
    
    $self->{'CheckMachineBarcode'} = LoadSql($dbh,"select equ_equipment_description, machine_number from equipment_informations 
               where bs_barcode = (select equinf_bs_barcode from process_steps_equipments where
               ps_ps_id = ? and equinf_bs_barcode = ?)", 'ListOfList');  
 
    $self->{'GetMachineBarcode'} = LoadSql($dbh,"select bs_barcode from equipment_informations where equ_equipment_description = ? and machine_number = ?", 'Single');  
    

    $self->{'CheckPlateType'} = LoadSql($dbh,"select barcode_description from barcode_sources where barcode = ?", 'Single');  
    $self->{'CheckIfAbandoned'} = LoadSql($dbh,"select count(*) from pse_barcodes, process_step_executions where pse_id = pse_pse_id and
               bs_barcode = ? and psesta_pse_status = 'abandoned'", 'Single');  

    
    
    $self->{'GetBarcodePrefixFromOutputDevice'} = LoadSql($dbh,"select distinct bp_barcode_prefix from process_steps where PSS_PROCESS_STEP_STATUS = 'active' and output_device = ?", 'List');

    $self->{'Prefix0f'} = LoadSql($dbh,"select cn_chemical_name, lot_number, (CONTAINER_COUNT-CONTAINER_USED) from chemical_informations where bs_barcode = ?", 'ListOfList');

    $self->{'Prefix0g'} = LoadSql($dbh,"select rn_reagent_name, batch_number, (CONTAINER_COUNT_STOCK-CONTAINER_USED_STOCK), (CONTAINER_COUNT_AVAILABLE-CONTAINER_USED_AVAILABLE)  from reagent_informations where bs_barcode = ?", 'ListOfList');

    $self->{'Prefix0h'} = LoadSql($dbh,"select first_name, last_name, gu_id from gsc_users where bs_barcode = ?", 'ListOfList');  
    
    $self->{'PrefixClone'} = LoadSql($dbh,"select clone_name from clones, clones_pses 
               where clo_id = clo_clo_id and pse_pse_id in 
               (select distinct pse_pse_id from pse_barcodes where bs_barcode = ? and direction = 'out')", 'Single');  
    $self->{'PrefixCloneLib'} = LoadSql($dbh,"select clone_name from clones, clones_pses 
               where clo_id = clo_clo_id and pse_pse_id in 
               (select distinct pse_pse_id from pse_barcodes where bs_barcode = ? and direction = 'out')", 'ListOfList');  
    $self->{'PrefixCloneGrowthLib'} = LoadSql($dbh,qq/select
--distinct substr(c.clone_name, 0, length(c.clopre_clone_prefix) + 4) || ' ' || s.sector_name
  distinct substr(c.clone_name, 0, length(c.clone_name) - 3) || ' ' || s.sector_name
from 
  process_step_executions pse, pse_barcodes pb, dna_pse dp, clone_growths cg, dna_pse dpi, clones c, dna_location dl, sectors s
where
  s.sec_id = dl.sec_id
and
  dpi.dl_id = dl.dl_id 
and
  dpi.dna_id = c.clo_id
and
  c.clo_id = cg.clo_clo_id
and
  dp.dna_id = cg.cg_id
and
  dp.pse_id = pse.pse_id
and
  pse.pse_id = pb.pse_pse_id 
and
  pb.bs_barcode = ?/, 'ListOfList');  
    $self->{'PrefixGrowth'} = LoadSql($dbh,"select clone_name, growth_ext  from clones, clone_growths 
               where clo_id = clo_clo_id and 
               cg_id in (select distinct cg_cg_id from clone_growths_pses where pse_pse_id in 
               (select pse_pse_id from pse_barcodes where bs_barcode = ? and direction = 'out'))", 'ListOfList');  

    $self->{'PrefixLibrary'} = LoadSql($dbh,"select distinct clone_name, library_number
               from 
               clones clo, clone_growths cg,
               clone_growths_libraries cgl,
	       clone_libraries cl,
               clone_libraries_pses clx,
               pse_barcodes barx, process_step_executions pse where
               clx.cl_cl_id = cl.cl_id and
               pse.pse_id = clx.pse_pse_id and
               clx.cl_cl_id = cgl.cl_cl_id and
               cgl.cg_cg_id = cg.cg_id and
               cg.clo_clo_id = clo.clo_id and
               barx.pse_pse_id = pse.pse_id and
               barx.bs_barcode = ? and barx.direction = 'out'", 'ListOfList');  

    $self->{'PrefixLibraryFromSubclone'} = LoadSql($dbh,"select distinct library_number, subclone_name
               from 
	       clone_libraries cl,
               clone_libraries_pses clx, subclones,
               pse_barcodes barx where
               clx.cl_cl_id = cl.cl_id and
               sub_id = sub_sub_id and
               clx.pse_pse_id =  barx.pse_pse_id and
               barx.bs_barcode = ? and barx.direction = 'in'", 'ListOfList');  

    $self->{'PrefixFraction'} = LoadSql($dbh,"select distinct clone_name, library_number, fraction_name
               from 
               clones clo, clone_growths cg,
               clone_growths_libraries cgl,
	       clone_libraries cl, fractions fr,
               fractions_pses frx,
               pse_barcodes barx, process_step_executions pse where
               fr.cl_cl_id = cl.cl_id and
               frx.fra_fra_id = fr.fra_id and
               pse.pse_id = frx.pse_pse_id and
               fr.cl_cl_id = cgl.cl_cl_id and
               cg.cg_id = cgl.cg_cg_id and
               cg.clo_clo_id = clo.clo_id and
               barx.pse_pse_id = pse.pse_id and
               barx.bs_barcode = ? and barx.direction = 'out'", 'ListOfList');  
   
    $self->{'PrefixLigation'} = LoadSql($dbh,"select distinct clone_name, library_number, ligation_name
               from 
               clones clo, clone_growths cg,
               clone_growths_libraries cgl,
	       clone_libraries cl, fractions fr, ligations lg,
               dna_pse lgx,
               pse_barcodes barx, process_step_executions pse where
               fr.cl_cl_id = cl.cl_id and
               lg.fra_fra_id = fr.fra_id and
               lg.lig_id = lgx.dna_id and
               pse.pse_id = lgx.pse_id and
               fr.cl_cl_id = cgl.cl_cl_id and
               cg.cg_id = cgl.cg_cg_id and
               cg.clo_clo_id = clo.clo_id and
               barx.pse_pse_id = pse.pse_id and
               barx.bs_barcode = ? and barx.direction = ?", 'ListOfList');  
   
    $self->{'PrefixSubclone'} = LoadSql($dbh,"select distinct clone_name, library_number, vector_name, an.archive_number, an.ap_purpose
               from 
               clones clo, clone_growths cg,
               clone_growths_libraries cgl,
	       clone_libraries cl, fractions fr, ligations lg, subclones sub, archives an, subclones_pses subx,
               pse_barcodes barx, process_step_executions pse, vector_linearizations vl, vectors where
               cg.clo_clo_id = clo.clo_id and
               cg.cg_id = cgl.cg_cg_id and
               fr.cl_cl_id = cl.cl_id and
               fr.cl_cl_id = cgl.cl_cl_id and
               lg.fra_fra_id = fr.fra_id and
               lg.lig_id = sub.lig_lig_id and
               lg.vl_vl_id = vl.vl_id and
               vl.vec_vec_id = vec_id and
               sub.sub_id = subx.sub_sub_id and
               an.arc_id = sub.arc_arc_id and
               pse.pse_id = subx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               barx.bs_barcode = ? and barx.direction = 'out'", 'ListOfList');  

   $self->{'PrefixFinSubclone'} = LoadSql($dbh,"select distinct clone_name, library_number, subclone_name
               from 
               clones clo, clone_growths cg,
               clone_growths_libraries cgl,
	       clone_libraries cl, fractions fr, ligations lg, subclones sub, subclones_pses subx,
               pse_barcodes barx, process_step_executions pse, vector_linearizations vl, vectors where
               cg.clo_clo_id = clo.clo_id and
               cg.cg_id = cgl.cg_cg_id and
               fr.cl_cl_id = cl.cl_id and
               fr.cl_cl_id = cgl.cl_cl_id and
               lg.fra_fra_id = fr.fra_id and
               lg.lig_id = sub.lig_lig_id and
               lg.vl_vl_id = vl.vl_id and
               vl.vec_vec_id = vec_id and
               sub.sub_id = subx.sub_sub_id and
               pse.pse_id = subx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               barx.bs_barcode = ? and barx.direction = 'out'", 'ListOfList');  

    $self->{'PrefixSequence'} = LoadSql($dbh,"select distinct clone_name, library_number, an.archive_number, an.ap_purpose
               from 
               clones clo, clone_growths cg,
               clone_growths_libraries cgl,
	       clone_libraries cl, fractions fr, ligations lg, subclones sub, archives an,
               pse_barcodes barx, process_step_executions pse, sequenced_dnas sd, seq_dna_pses sdx, vector_linearizations vl, vectors where
               cg.clo_clo_id = clo.clo_id and
               cg.cg_id = cgl.cg_cg_id and
               fr.cl_cl_id = cgl.cl_cl_id and
               fr.cl_cl_id = cl.cl_id and
               lg.fra_fra_id = fr.fra_id and
               lg.lig_id = sub.lig_lig_id and
               lg.vl_vl_id = vl.vl_id and
               vl.vec_vec_id = vec_id and
               sub.sub_id = sd.sub_sub_id and 
               sd.seqdna_id = sdx.seqdna_seqdna_id and
               an.arc_id = sub.arc_arc_id and
               pse.pse_id = sdx.pse_pse_id and
               barx.pse_pse_id = pse.pse_id and
               barx.bs_barcode = ? and barx.direction = 'out'", 'ListOfList');  

$self->{'PrefixEquip'} = LoadSql($dbh, qq/select distinct equ_equipment_description, machine_number
					 from equipment_informations where 
					 bs_barcode = ?/, 'ListOfList');

$self->{'PrefixGenome'} = LoadSql($dbh,qq/select distinct genome_name from genome g, genome_pse gp
				  where g.gn_id = gp.gn_id and pse_id in 
				  (select distinct pse_pse_id from pse_barcodes where bs_barcode = ? and direction = 'out')/, 'Single');  

$self->{'PrefixPse'} = LoadSql($dbh,qq/select distinct pse_pse_id from pse_barcodes where bs_barcode = ? and direction = 'out'/, 'List');  
$self->{'PrefixPcr'} = LoadSql($dbh,qq/select distinct pcr_name from pcr_product pcr, pcr_pse pp
			       where pp.pcr_id = pcr.pcr_id and pse_id = ?/, 'Single');  


$self->{'ReagentEvent'} = LoadSql($dbh,"insert into reagent_used_pses (pse_pse_id, RI_BS_BARCODE) values (?,?)", 'i');
$self->{'InsertPsePsoInfo'} = LoadSql($dbh,"insert into pse_data_outputs (pse_pse_id, pso_pso_id, data_value) values (?,?,?)", 'i');
$self->{'EquipmentEvent'} = LoadSql($dbh,"insert into pse_equipment_informations (equinf_bs_barcode, pse_pse_id)values (?, ?)", 'i');
$self->{'GetArchiveInfo'} = LoadSql($dbh, "select distinct archive_number
                 from archives an,
                      process_step_executions pse,
                      pse_barcodes psebc,
                      subclones_pses scp,
                      subclones sc
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
                                       where PSS_PROCESS_STEP_STATUS = 'active' and
                                       pro_process_to in ('pick', 'archive growth','generate archive plate barcode'))", 'List');

$self->{'GetEquipmentInfo'} = LoadSql($dbh, "select EIS_EQUIPMENT_STATUS, EQU_EQUIPMENT_DESCRIPTION, unit_name from equipment_informations where bs_barcode = ?", 'ListOfList');
    $self -> {'GetEquipChildren'} = LoadSql($dbh,"select distinct bs_barcode, unit_name from equipment_informations where equinf_bs_barcode = ? order by lpad(unit_name,3)", 'List');


    $self -> {'GetArcFromBar'} = LoadSql($dbh, "select distinct bs_barcode, pse_pse_id from pse_barcodes where 
               direction = 'in' and pse_pse_id in (
               select distinct max(pse_id) from process_step_executions where 
               psesta_pse_status = 'completed' and ps_ps_id in 
               (select ps_id from process_steps
               where PSS_PROCESS_STEP_STATUS = 'active' and 
               pro_process_to in ('assign archive plate to storage location', 'assign freezer box to storage location', 'assign tube to freezer box location' )) and
               pse_id in 
               (select pse_pse_id from pse_equipment_informations where equinf_bs_barcode = ?))", 'ListOfList');
             
$self->{'GetBarcodeHistory'} = LoadSql($dbh, "select pse_pse_id, direction from pse_barcodes
               where  bs_barcode = ? order by pse_pse_id", 'ListOfList');
#LSF: Changed this substr(c.clone_name, 0, length(c.clopre_clone_prefix) + 4) to substr(c.clone_name, 0, length(c.clone_name) - length(ltrim(substr(c.clone_name, length(c.clopre_clone_prefix) + 1, length(c.clone_name) - length(c.clopre_clone_prefix)), '-0123456789')))
$self->{'GetEquipmentHistory'} = LoadSql($dbh, q/select
  distinct dp.pse_id, pb.bs_barcode || ' ' || 
  substr(c.clone_name, 0, length(c.clone_name) - length(ltrim(substr(c.clone_name, length(c.clopre_clone_prefix) + 1, length(c.clone_name) - length(c.clopre_clone_prefix)), '-0123456789'))) 
  || ' ' || s.sector_name, ei.equ_equipment_description || ' ' || ei.machine_number, pse.date_scheduled
from 
  (select bs_barcode from equipment_informations start with bs_barcode like ? connect by equinf_bs_barcode = prior bs_barcode) eh, process_step_executions pse, pse_equipment_informations pei, equipment_informations ei, pse_barcodes pb, dna_pse dp, clone_growths cg, dna_pse dpi, clones c, dna_location dl, sectors s
where
  s.sec_id = dl.sec_id
and
  dpi.dl_id = dl.dl_id 
and
  dpi.dna_id = c.clo_id
and
  cg.clo_clo_id = c.clo_id
and
  cg.cg_id = dp.dna_id
and
  dp.pse_id = pse.pse_id
and
  pse.pse_id = pb.pse_pse_id 
and 
  pse.pse_id = pei.pse_pse_id 
and 
  pse.psesta_pse_status = 'inprogress' 
and 
  ei.bs_barcode = pei.equinf_bs_barcode 
and 
  pei.equinf_bs_barcode  = eh.bs_barcode order by dp.pse_id, pse.date_scheduled/, 'ListOfList');
  
  $self->{'GetEquipmentHistory_old'} = LoadSql($dbh, q/select
  distinct dp.pse_id, pb.bs_barcode || ' ' || 
  substr(c.clone_name, 0, length(c.clone_name) - length(ltrim(substr(c.clone_name, length(c.clopre_clone_prefix) + 1, length(c.clone_name) - length(c.clopre_clone_prefix)), '-0123456789'))) 
  || ' ' || s.sector_name, ei.equ_equipment_description || ' ' || ei.machine_number, pse.date_scheduled
from 
  process_step_executions pse, pse_equipment_informations pei, equipment_informations ei, pse_barcodes pb, dna_pse dp, clone_growths cg, dna_pse dpi, clones c, dna_location dl, sectors s
where
  s.sec_id = dl.sec_id
and
  dpi.dl_id = dl.dl_id 
and
  dpi.dna_id = c.clo_id
and
  cg.clo_clo_id = c.clo_id
and
  cg.cg_id = dp.dna_id
and
  dp.pse_id = pse.pse_id
and
  pse.pse_id = pb.pse_pse_id 
and 
  pse.pse_id = pei.pse_pse_id 
and 
  pse.psesta_pse_status = 'inprogress' 
and 
  ei.bs_barcode = pei.equinf_bs_barcode 
and 
  pei.equinf_bs_barcode in (select bs_barcode from equipment_informations start with bs_barcode = ? connect by equinf_bs_barcode = prior bs_barcode) order by dp.pse_id, pse.date_scheduled/, 'ListOfList');

$self->{'GetEquipmentHistoryWithoutDNA'} = LoadSql($dbh, q/select
    distinct pse.pse_id, eii.bs_barcode || ' ' ||  eii.equ_equipment_description || ' ' || nvl(eii.unit_name, eii.machine_number) , '', pse.date_scheduled
  from 
    process_step_executions pse, 
    process_steps ps, 
    equipment_informations ei, 
    equipment_informations eii, 
    pse_equipment_informations pei, 
    pse_equipment_informations peii 
  where 
    pse.pse_id = peii.pse_pse_id 
  and
    ps.ps_id = pse.ps_ps_id 
  and
    eii.bs_barcode = peii.equinf_bs_barcode 
  and 
    peii.pse_pse_id = pei.pse_pse_id 
  and 
    ei.bs_barcode = pei.equinf_bs_barcode 
  and 
    pse.psesta_pse_status in ('inprogress', 'scheduled') 
  and
    ei.bs_barcode in (
       select 
         bs_barcode 
       from 
         equipment_informations 
       start with 
         bs_barcode = ? 
       connect by 
         equinf_bs_barcode = prior bs_barcode) order by pse.pse_id, pse.date_scheduled
/, 'ListOfList');

$self->{'GetEquipmentContain'} = LoadSql($dbh, q{select 
  distinct dp.pse_id, pb.bs_barcode || ' ' ||
  substr(c.clone_name, 0, length(c.clone_name) - length(ltrim(substr(c.clone_name, length(c.clopre_clone_prefix) + 1, length(c.clone_name) - length(c.
clopre_clone_prefix)), '-0123456789')))
  || ' ' || s.sector_name, ei.equ_equipment_description || ' ' || ei.machine_number, pse.date_scheduled
from
  process_step_executions pse
  join pse_equipment_informations pei on pei.pse_pse_id = pse.pse_id
  join equipment_informations ei on ei.bs_barcode = pei.equinf_bs_barcode
  join pse_barcodes pb on pb.pse_pse_id = pse.pse_id
  join dna_pse dp on dp.pse_id = pse.pse_id
  join dna_relationship cg on cg.dna_id = dp.dna_id
  join clones c on c.clo_id = cg.parent_dna_id
  join dna_pse dpi on dpi.dna_id = c.clo_id
  join dna_location dl on dl.dl_id = dpi.dl_id
  join sectors s on s.sec_id = dl.sec_id
where
  pse.psesta_pse_status = 'inprogress'
and  ei.bs_barcode = pei.equinf_bs_barcode
and  pei.equinf_bs_barcode = ? order by dp.pse_id, pse.date_scheduled

}, 'ListOfList');


####### Project Queries ###########
	my $project_queries = $self->{'project_queries'} = {};
	$project_queries -> {'projects_pses'} = LoadSql($dbh, "select distinct project_project_id from projects_pses where pse_pse_id = ?", 'List');
	$project_queries -> {'clones_pses'} = LoadSql($dbh,"select distinct project_project_id from clones_pses, clones, clones_projects
                                                where clo_id = clones_pses.clo_clo_id and clo_id = clones_projects.clo_clo_id and pse_pse_id = ?", 'List');
	$project_queries -> {'clone_growths_pses'} = LoadSql($dbh,"select distinct project_project_id from clone_growths_pses, clone_growths, clones_projects
                                                where clone_growths_pses.cg_cg_id = cg_id and clone_growths.clo_clo_id = clones_projects.clo_clo_id and pse_pse_id = ?", 'List');
	$project_queries -> {'clone_libraries_pses'} = LoadSql($dbh,"select distinct project_project_id from clone_libraries_pses, clone_growths, 
                                                clone_growths_libraries, clones_projects
                                                where clone_growths.clo_clo_id = clones_projects.clo_clo_id and pse_pse_id = ? and 
                                                clone_libraries_pses.cl_cl_id = clone_growths_libraries.cl_cl_id and  cg_id = clone_growths_libraries.cg_cg_id", 'List');
	$project_queries -> {'fractions_pses'} = LoadSql($dbh,"select distinct project_project_id from fractions_pses, fractions, clone_growths, 
                                                clone_growths_libraries, clones_projects
                                                where clone_growths.clo_clo_id = clones_projects.clo_clo_id and pse_pse_id = ? and 
                                                cg_id = clone_growths_libraries.cg_cg_id and fractions.cl_cl_id = clone_growths_libraries.cl_cl_id
                                                and fra_id = fra_fra_id", 'List');
	$project_queries -> {'ligations_pses'} = LoadSql($dbh,"select distinct project_project_id from dna_pse lgx, ligations, fractions, 
                                                clone_growths, clone_growths_libraries, clones_projects
                                                where clone_growths.clo_clo_id = clones_projects.clo_clo_id and pse_id = ? and fractions.cl_cl_id = clone_growths_libraries.cl_cl_id
                                                and cg_id = clone_growths_libraries.cg_cg_id and fra_id = fra_fra_id and lig_id = lgx.dna_id", 'List');

	$project_queries -> {'subclones_pses'} = LoadSql($dbh,"select distinct project_project_id from subclones_pses, subclones, fractions, 
                                                ligations, clone_growths, clone_growths_libraries, clones_projects
                                                where clone_growths.clo_clo_id = clones_projects.clo_clo_id and pse_pse_id = ? and 
                                                fractions.cl_cl_id = clone_growths_libraries.cl_cl_id
                                                and cg_id = clone_growths_libraries.cg_cg_id and fra_id = fra_fra_id and lig_id = lig_lig_id and sub_id = subclones_pses.sub_sub_id", 'List');

	$project_queries -> {'seq_dna_pses'} = LoadSql($dbh,"select distinct project_project_id from seq_dna_pses, sequenced_dnas, fractions, 
                                                ligations, clone_growths, clone_growths_libraries, clones_projects, subclones
                                                where clone_growths.clo_clo_id = clones_projects.clo_clo_id and pse_pse_id = ? and fractions.cl_cl_id = clone_growths_libraries.cl_cl_id
                                                and cg_id = clone_growths_libraries.cg_cg_id and fra_id = fra_fra_id and lig_id = lig_lig_id and sub_id = sequenced_dnas.sub_sub_id and seqdna_id = seqdna_seqdna_id", 'List');

       $project_queries -> {'project_attributes'} = LoadSql($dbh, "select name, pp_purpose, prosta_project_status, priority, NULL, target, NULL, estimated_size, no_contigs, no_assemble_traces, date_last_assembled from projects where project_id = ?", 'ListOfList');
	
       $project_queries -> {'project_archives'} = LoadSql($dbh,"select distinct arc_id from 
                                                             ligations, fractions, clone_growths, clone_growths_libraries, 
                                                             clones_projects, subclones, archives
                                                             where project_project_id = ? and clones_projects.clo_clo_id = clone_growths.clo_clo_id and
                                                             lig_lig_id = lig_id and fra_id = fra_fra_id and fractions.cl_cl_id = clone_growths_libraries.cl_cl_id and
                                                             cg_id = clone_growths_libraries.cg_cg_id and arc_arc_id = arc_id and ap_purpose != 'qc'", 'List');

    $project_queries -> {'active_qc'} = LoadSql($dbh, "select distinct data_value, lig_id from process_step_outputs, pse_data_outputs,
                                                  dna_pse lgx, process_step_executions pse, process_steps, ligations, 
                                                  fractions, clone_growths_libraries, clone_growths, clones, clones_projects where
                                                  pso_id = pso_pso_id and 
                                                  output_description = 'pick qc' and
                                                  pse.pse_id = lgx.pse_id and 
                                                  pse.pse_id = pse_data_outputs.pse_pse_id and
                                                  process_step_outputs.ps_ps_id = ps_id and 
                                                  pse.ps_ps_id = ps_id and 
                                                  pro_process_to = 'confirm dilution' and 
                                                  ((psesta_pse_status='inprogess') or ((psesta_pse_status='completed') and (pr_pse_result='successful'))) and
                                                  lig_id = lgx.dna_id and 
                                                  fra_id = fra_fra_id and 
                                                  fractions.cl_cl_id = clone_growths_libraries.cl_cl_id and 
                                                  clone_growths_libraries.cg_cg_id = cg_id and 
                                                  clone_growths.clo_clo_id = clo_id and 
                                                  clones_projects.clo_clo_id = clo_id and
                                                  project_project_id = ?", 'ListOfList');

$project_queries -> {'qc_picked'} = LoadSql($dbh,"select distinct arc_id from 
                                                             subclones, archives
                                                             where lig_lig_id = ? and  arc_arc_id = arc_id and ap_purpose = 'qc'", 'Single');

##################

    ############ Clone History Queries ##################
    my $clone_queries = $self->{'CloneHistoryQueries'} = {};
    $clone_queries->{'clones.clo_id'} = LoadSql($dbh,"select distinct clo_clo_id from clones_pses where pse_pse_id = ?", 'Single');  
    $clone_queries->{'clone_growths.clo_id'} = LoadSql($dbh,"select distinct clo_clo_id from clone_growths, clone_growths_pses 
                                               where cg_id =  clone_growths_pses.cg_cg_id and pse_pse_id = ?", 'Single');
    $clone_queries -> {'clones.pse_id'} = LoadSql($dbh,"select distinct pse_pse_id from clones_pses                                                                                                 where clo_clo_id = ?", 'List');
    $clone_queries -> {'clone_growths.pse_id'} =  LoadSql($dbh,"select distinct pse_pse_id from clone_growths, clone_growths_pses 
                                                     where cg_id =  clone_growths_pses.cg_cg_id and clo_clo_id = ?", 'List');
    
    
    $clone_queries -> {'clones.info'} = LoadSql($dbh,"select distinct clone_name, NULL from clones_pses, clones
                                                where clo_id = clo_clo_id and pse_pse_id = ?", 'ListOfList');
    $clone_queries -> {'clone_growths.info'} =  LoadSql($dbh,"select distinct clone_name, growth_ext from clone_growths_pses, 
                                                            clone_growths, clones
                                                            where pse_pse_id = ? and cg_id =  clone_growths_pses.cg_cg_id and clo_clo_id = clo_id 
                                                            ", 'ListOfList');

    $clone_queries -> {'clone_growths_check'} =  LoadSql($dbh,qq/select distinct clone_name, growth_ext from 
								 process_step_executions, clone_growths, clones, pse_barcodes,clone_growths_pses
							 where 
							 direction = 'out' and bs_barcode = ? and
							 cg_id =  clone_growths_pses.cg_cg_id and clo_clo_id = clo_id and 
							 pse_barcodes.pse_pse_id = pse_id and
							 pse_id = clone_growths_pses.pse_pse_id
							 /, 'ListOfList');

    #####################################################


############## Library History Queries ######################
    my $lib_queries =  $self -> {'LibraryQuries'} = {};
    $lib_queries->{'clone_libraries.cl_id'} =  LoadSql($dbh, "select distinct cl_cl_id from clone_libraries_pses where pse_pse_id = ?",'Single');
    $lib_queries->{'fractions.cl_id'} =  LoadSql($dbh, "select distinct cl_cl_id from fractions, fractions_pses where 
                                           fra_id = fra_fra_id and pse_pse_id = ?",'Single');
    $lib_queries->{'ligations.cl_id'} =  LoadSql($dbh, "select distinct cl_cl_id from fractions, ligations, dna_pse lgx where 
                                           lgx.dna_id = lig_id and fra_fra_id = fra_id and lgx.pse_id = ?",'Single');
    
    $lib_queries->{'clone_libraries.pses'} = LoadSql($dbh, "select distinct pse_pse_id from clone_libraries_pses where cl_cl_id = ?",'List');
    $lib_queries->{'fractions.pses'} = LoadSql($dbh, "select distinct pse_pse_id from fractions, fractions_pses where 
                                             fra_id = fra_fra_id and  cl_cl_id = ?",'List');
    $lib_queries->{'ligations.pses'} = LoadSql($dbh, "select distinct pse_id from fractions, ligations, dna_pse lgx where 
                                           lgx.dna_id = lig_id and fra_fra_id = fra_id and cl_cl_id = ?",'List');
    
     
    $lib_queries -> {'clone_libraries'} =  LoadSql($dbh, "select distinct cl_cl_id from clone_libraries_pses
                                                  where pse_pse_id = ?",'Single');
    $lib_queries -> {'fractions'} =  LoadSql($dbh, "select distinct cl_cl_id from fractions_pses, fractions
                                                  where fra_id = fra_fra_id and pse_pse_id = ?",'Single');
    $lib_queries -> {'ligations'} =  LoadSql($dbh, "select distinct cl_cl_id from fractions, ligations, dna_pse lgx where 
                                           lgx.dna_id = lig_id and fra_fra_id = fra_id and lgx.pse_id = ?",'Single');
   
   $lib_queries -> {'clo_id_sql1'} = LoadSql($dbh, "select distinct clo_clo_id, growth_ext from clone_growths where cg_id in (select cg_cg_id
                                         from clone_growths_libraries where cl_cl_id = ?)", 'ListOfList');

    
    $lib_queries -> {'clo_id_sql2'} = LoadSql($dbh, "select distinct clo_clo_id, growth_ext from clone_growths where cg_id in (select cg_cg_id 
                    from clone_growths_libraries where cl_cl_id in (select cl_cl_id from fractions where 
                    fra_id = (select fra_fra_id from ligations where lig_id in (select lig_lig_id from subclones 
                    where sub_id in (select sub_sub_id from clone_libraries where cl_id = ?)))))", 'ListOfList');;

    $lib_queries -> {'clone_sql'} = LoadSql($dbh, "select clone_name from clones where clo_id = ?", 'Single');
    
    $lib_queries -> {'library_sql'} = LoadSql($dbh, "select library_number from clone_libraries where cl_id = ?", 'Single');
    $lib_queries -> {'fraction_sql'} = LoadSql($dbh, "select distinct library_number, fraction_name from clone_libraries, fractions, fractions_pses where cl_id = cl_cl_id and fra_id = fra_fra_id and cl_cl_id = ? and pse_pse_id = ?", 'ListOfList');
    $lib_queries -> {'ligation_sql'} =  LoadSql($dbh, "select distinct library_number, fraction_name, ligation_name from clone_libraries, fractions, ligations, dna_pse lgx where  cl_id = cl_cl_id and fra_fra_id = fra_id and 
                lgx.dna_id = lig_id and lgx.pse_id = ? and cl_cl_id = ?", 'ListOfList');;


#############################################

    ############## Archive history queries #####################
    my $arch_queries = $self->{'ArchiveQueries'} = {};

    $arch_queries -> {'archives.arc_id'} = LoadSql($dbh,"select distinct arc_id from archives, archives_pses 
                                          where pse_pse_id = ?  and  arc_arc_id = arc_id",'Single');  
    $arch_queries -> {'subclones.arc_id'} = LoadSql($dbh, "select distinct arc_arc_id from subclones_pses, subclones
                                           where pse_pse_id = ? and sub_sub_id = sub_id",'Single');  
    $arch_queries -> {'seq_dna.arc_id'} = LoadSql($dbh, "select distinct arc_arc_id from subclones, seq_dna_pses, sequenced_dnas
                                         where pse_pse_id = ? and sub_sub_id = sub_id and seqdna_id = seqdna_seqdna_id",'Single');  

    $arch_queries -> {'archives.pse_id'} = LoadSql($dbh, "select distinct pse_pse_id from archives_pses where arc_arc_id = ?",'List');
    $arch_queries -> {'subclones.pse_id'} = LoadSql($dbh, "select distinct pse_pse_id from subclones_pses, subclones
                                             where   arc_arc_id = ? and sub_sub_id = sub_id",'List');
    $arch_queries -> {'seq_dna.pse_id'} = LoadSql($dbh, "select distinct pse_pse_id from subclones, seq_dna_pses, sequenced_dnas
                                      where  arc_arc_id = ? and sub_sub_id = sub_id and seqdna_id = seqdna_seqdna_id",'List');
    $arch_queries -> {'traces.pse_id'} = LoadSql($dbh, "select distinct pse_pse_id from subclones, sequenced_dnas, traces, traces_pses
                                      where arc_arc_id = ? and sub_sub_id = sub_id and seqdna_id = seqdna_seqdna_id
                                       and tra_tra_id = tra_id",'List');
    $arch_queries -> {'read_exps.pse_id'} = LoadSql($dbh, "select distinct pse_pse_id from subclones, sequenced_dnas, traces, read_exps,
                                         read_exps_pses where  arc_arc_id = ? and  sub_sub_id = sub_id 
                                         and seqdna_id = seqdna_seqdna_id and
                                         tra_tra_id = tra_id and re_id = re_re_id ",'List');
    
    $arch_queries -> {'archives'} = LoadSql($dbh, "select distinct arc_arc_id, NULL from archives_pses where pse_pse_id = ?",'ListOfList');
    $arch_queries -> {'subclones'} = LoadSql($dbh, "select distinct arc_arc_id, sector_name from subclones,  subclones_pses,                                                         plate_locations, sectors where pse_pse_id = ? and                                                          sub_sub_id = sub_id and pl_pl_id = pl_id and sec_sec_id = sec_id",'ListOfList');

    $arch_queries -> {'seq_dna'} = LoadSql($dbh, "select distinct arc_arc_id, sector_name from subclones,  plate_locations,  sectors, sequenced_dnas, seq_dna_pses where pse_pse_id = ? and  seqdna_seqdna_id = seqdna_id and pl_pl_id = pl_id and sec_sec_id = sec_id and  sub_sub_id = sub_id",'ListOfList');

    $arch_queries -> {'traces'} = LoadSql($dbh, "select distinct arc_arc_id, NULL from subclones, sequenced_dnas,  traces, traces_pses where pse_pse_id = ? and tra_tra_id = tra_id and  seqdna_seqdna_id = seqdna_id and sub_sub_id = sub_id",'ListOfList');

    $arch_queries -> {'read_exps'} = LoadSql($dbh, "select distinct arc_arc_Id, NULL from subclones, sequenced_dnas, 
                                            traces,
                                            read_exps, read_exps_pses where pse_pse_id = ? and re_re_id = re_id and 
                                            tra_tra_id = tra_id and seqdna_seqdna_id = seqdna_id and sub_sub_id = sub_id",'ListOfList');

$arch_queries -> {'lig_id'} = LoadSql($dbh, "select distinct lig_lig_id from subclones where arc_arc_id = ?", 'Single');

$arch_queries -> {'fra_id'} = LoadSql($dbh, "select distinct fra_fra_id, ligation_name from ligations where lig_id = ?", 'ListOfList');
$arch_queries -> {'cl_id'} = LoadSql($dbh, "select distinct cl_cl_id from fractions where fra_id = ?", 'Single');
	
$arch_queries -> {'library_number'} = LoadSql($dbh, "select library_number from clone_libraries where cl_id = ?", 'Single');
$arch_queries -> {'cg_id'} = LoadSql($dbh, "select  distinct cg_cg_id from clone_growths_libraries where cl_cl_id = ?", 'Single');
$arch_queries -> {'clo_id'} = LoadSql($dbh, "select clo_clo_id from clone_growths where cg_id = ?", 'Single');
$arch_queries -> {'clone_name'} = LoadSql($dbh, "select clone_name from clones where clO_id = ?", 'Single');

    $arch_queries -> {'clone_sql'} = LoadSql($dbh, "select distinct clone_name from 
                                     clones, clone_growths, clone_growths_libraries where 
                                     clo_id = clo_clo_id and
                                     cg_id  = clone_growths_libraries.cg_cg_id and
                                     clone_growths_libraries.cl_cl_id = ?", 'Single');
    $arch_queries -> {'arc_sql'} = LoadSql($dbh, "select distinct archive_number, ap_purpose from archives where arc_id = ?", 'ListOfList');
   
    
   $arch_queries -> {'library_ligation_sql'} = LoadSql($dbh, "select distinct library_number, ligation_name, cl_id from clone_libraries,
                                           fractions fr, ligations where
                                           fra_id = fra_fra_id  and fr.cl_cl_id = cl_id and
                                           lig_id in (select distinct lig_lig_id from subclones where arc_arc_id = ?)", 'ListOfList');
    ##################################################


    $self -> {'bar_sql'} = LoadSql($dbh, "select bs_barcode from pse_barcodes where pse_pse_id = ? and direction = ?", 'Single');
    $self -> {'process_to_sql'} = LoadSql($dbh, "select pro_process_to from process_steps where ps_id = 
                                            (select ps_ps_id from process_step_executions where pse_id = ?)", 'Single');
    $self -> {'pse_info'} = LoadSql($dbh, "select DATE_COMPLETED, PSESTA_PSE_STATUS, pr_pse_result, pse_session from process_step_executions 
                                      where pse_id = ?", 'ListOfList');

    $self -> {'unix_sql'} = LoadSql($dbh, "select distinct unix_login from gsc_users where gu_id = 
                                      (select gu_gu_id from employee_infos where ei_id = 
                                      (select ei_ei_id from process_step_executions where pse_id = ?))", 'Single');


     
    # directed sequencing history querries #
    $self -> {'CheckProcess'} = LoadSql($dbh, "select distinct pro_process_to from process_steps where ps_id in (select ps_ps_id from 
                                                       process_step_executions where pse_id = ?)", 'Single');
    
    $self -> {'GetPreBarPse'} = LoadSql($dbh, "select bs_barcode, pse_pse_id from pse_barcodes where direction = 'in' and pse_pse_id in (
                                                       select pse_pse_id from pse_barcodes where bs_barcode = ? and direction = 'out')", 'ListOfList');
    

    $self -> {'PrefinishDyeChem'} = LoadSql($dbh, "select distinct dyetyp_dye_name, dc_id, enzyme_name, enz_id, pd_primer_direction, primer_type from 
                                                   direct_seq_pses dp, direct_seq, pse_barcodes pb, enzymes,
                                                   primers, dye_chemistries where bs_barcode = ? and direction = 'out' and
                                                   pb.pse_pse_id = dp.pse_pse_id and ds_ds_id = ds_id and pri_pri_id = pri_id and
                                                   dc_dc_id = dc_id and enz_enz_id = enz_id", 'ListOfList');

    $self -> {'PrefinishDyeChemFromOligo'} = LoadSql($dbh, "select distinct dyetyp_dye_name, dc_id, enzyme_name, enz_id, pd_primer_direction, primer_type from 
                                                   custom_primer_pse cp, direct_seq ds, pse_barcodes pb, enzymes,
                                                   primers, dye_chemistries where bs_barcode = ? and direction = 'out' and
                                                   pb.pse_pse_id = cp.pse_pse_id and cp.dna_id = ds.dna_id and 
                                                   cp.pri_pri_id = ds.pri_pri_id and ds.pri_pri_id = pri_id and
                                                   dc_dc_id = dc_id and enz_enz_id = enz_id", 'ListOfList');

    $self->{'PrefixPrimer'} =  LoadSql($dbh, "select distinct p.primer_name 
	from primers p, custom_primer_pse cp, pse_barcodes pb
	where 
	p.pri_id = cp.pri_pri_id 
	and pb.pse_pse_id = cp.pse_pse_id 
	and bs_barcode = ?", 'Single');
 
$SINGLETON = $self;
return $self;

} #new

################################
# Commit Database Transactions #
################################
sub commit {
    my ($self) = @_;
    $self->{'dbh'}->commit if($SINGLETON);
} #commit

################################
# Commit Database Transactions #
################################
sub rollback {
    my ($self) = @_;
    $self->{'dbh'}->rollback if($SINGLETON);
} #commit

###################################
# Destroy an instance of TouchSql #
###################################
sub destroy {
    my ($self) = @_;
    undef %{$self}; 
    $SINGLETON = undef;
    $self ->  DESTROY;
    $self = undef;
} #destroy
   
############################################################################################
#                                                                                          #
#                            Main Subrotine Processes                                      #
#                                                                                          #
############################################################################################


    
############################################################################################
#                                                                                          #
#                       TOUCH SCREEN LOGIN STEP QUERRIES                                   #
#                                                                                          #
############################################################################################



##############################################
# Determines the Unix login from employee id #
##############################################
sub GetUnixLogin {
    my ($self, $ei_id) = @_;

    my $unix_login = $self->{'GetUnixLogin'} -> xSql($ei_id);
    
    if($unix_login ne '') {
	return $unix_login;
    }

    $Error = "$pkg: Could not get unix_login from ei_id = $ei_id.";
    $Error = $Error." $DBI::errstr" if(defined $DBI::errstr);
   
    return 0;
} #GetUnixLogin

###########################################
# Get Employee information from a barcode #
###########################################
sub GetEmployeeInfo {

    my ($self, $barcode) = @_;
    
    my $employee_info = $self->{'GetEmployeeInfo'} -> xSql($barcode);

    if(defined $employee_info->[0][0]) {
	return $employee_info;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not get employee information from barcode = $barcode.";
    }
    
    return 0;

} #GetEmployeeInfo

#################################
# Get User barcode from user_id #
#################################
sub GetBarcodeFromUseId {
    
    my ($self, $userid) = @_;

    # Retrieve the Barcode Id for user id enter 
    my $barcodeid = $self->{'GetBarcodeFromUseId'} -> xSql($userid);

    if(defined $barcodeid) {
	return $barcodeid;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not get barcode from user_id = $userid.";
    }
    
    return 0;

} #GetBarcodeFromUseId


########################
# Get the users Groups #
########################
sub GetUserGroups {

    my ($self, $userid) = @_;

    my $grp_ref = $self->{'GetUserGroups'} -> xSql($userid);
    
    if(defined $grp_ref->[0]) {
	return $grp_ref;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not get user groups where use_id = $userid.";
    }
    
    return 0;

} #GetUserGroups

##################
# Get Employe ID #
##################
sub GetEmployeeId {

    my ($self, $userid, $group) = @_;
    #LSF: If the employee is in "development", it is fine for all the group.
    my $ei = GSC::EmployeeInfo->get(gu_id => $userid, group_name => ['development', 'mcclintock'], user_status => 'active');
    my $employeeid = $ei ? $ei->ei_id : $self->{'GetEmployeeId'} -> xSql($userid, $group);

    if(defined $employeeid) {
	return $employeeid;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not get employee_id where user_id = $userid and group = $group.";
    }
    
    return 0;

} #GetEmployeeId

#######################
# Get Groups Purposes #
#######################
sub GetGroupPurposes {
    my ($self, $group) = @_;
    
    my $purp_ref = $self->{'GetGroupPurposes'} -> xSql($group);

    if(defined $purp_ref->[0]) {
	return $purp_ref;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not get purposes where group = $group.";
    }
    
    return 0;

    
} #GetGroupPurposes 


################################
# Check if user is boss status #
################################
sub CheckIfBoss {

    my ($self, $useid) = @_;

    my $count = $self->{'CheckIfBoss'} -> xSql($useid);
    if($count > 0) {
	return 1;
    }
    
    return 0;
} #CheckIfBoss


##############################
# Get list of User Processes #
##############################
sub GetProcesses {
    
    my ($self, $group, $purpose, $ei_id) = @_;
    
    ################################################
    # Retrieve all process steps that are barcoded #
    ################################################
    my $process_steps_ref = $self->{'GetProcesses'} -> xSql($group,$purpose);
    

    if(defined $process_steps_ref->[0][0]) {
	my $list = [];
	foreach my $proc (@{$process_steps_ref}) {
	    my $permissions = $self -> {'CountProcessEmps'} -> xSql($proc->[2]);
	    if($permissions) {
		$permissions = $self -> {'CountMatchProcessEmps'} ->  xSql($proc->[2], $ei_id);
	    }
	    else {
		$permissions = 1;
	    }

	    if($permissions) {
		
		my $found = 0;
		foreach my $val (@{$list}) {
		    if($val eq $proc->[0]) {
			$found = 1;
			last;
		    }
		    
		}
		if(!$found) {
		    push(@{$list}, $proc->[0]);
		}
	    }
	}
	return $list;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find processes for group = $group, purpose = $purpose.";
    }	

    return 0;
} #GetProcesses 

#####################
# Get Input Devices #
#####################
sub GetInputDevices {

    my ($self, $group, $purpose, $process) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};

    my $output_dev_ref = $self->{'GetInputDevices'} -> xSql($process, $group, $purpose);
    if(defined $output_dev_ref->[0]) {
	return $output_dev_ref;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find input devices for group = $group, purpose = $purpose, process = $process.";
    }	

    return 0;

} #GetInputDevices


######################
# Get Output Devices #
######################
sub GetOutputDevices {

    my ($self, $group, $purpose, $process, $ei_id, $inputdev) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    my $output_dev_ref;
    if(defined $inputdev) {
	$output_dev_ref = $self->{'GetOutputDevicesFromInput'} -> xSql($process, $group, $purpose, $inputdev);
    }
    else {
	$output_dev_ref = $self->{'GetOutputDevices'} -> xSql($process, $group, $purpose);
    }
    if(defined $output_dev_ref->[0][0]) {
	my $list = [];
	foreach my $proc (@{$output_dev_ref}) {
	    my $permissions = $self -> {'CountProcessEmps'} -> xSql($proc->[1]);
	    if($permissions) {
		$permissions = $self -> {'CountMatchProcessEmps'} ->  xSql($proc->[1], $ei_id);
	    }
	    else {
		$permissions = 1;
	    }

	    if($permissions) {
		
		my $found = 0;
		foreach my $val (@{$list}) {
		    if($val eq $proc->[0]) {
			$found = 1;
			last;
		    }
		    
		}
		if(!$found) {
		    push(@{$list}, $proc->[0]);
		}
	    }
	}
	return $list;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find output devices for group = $group, purpose = $purpose, process = $process.";
    }	

    return 0;

} #GetOutputDevices



sub GetProcessInfo {

    my ($self, $group, $purpose, $process, $outputdev, $inputdev) = @_;
    
    ##############################################################
    # querry for the barcode prefix of the selected process step #
    ##############################################################
    my $info_ref;
    if(defined $inputdev) {
	my $prefixes = $self->{'GetBarcodePrefixFromOutputDevice'} -> xSql($inputdev);

	foreach my $prefix (@$prefixes) {
	    $info_ref = $self->{'GetProcessInfoWithInput'} -> xSql($process, $group, $purpose, $outputdev, $prefix, $prefix);
	    my @t;
	    foreach my $c (@$info_ref) {
	      if($c->[1] eq $prefix) {
	        push @t, $c;
	      }
	    }
	    if(@t) {
	      $info_ref = \@t;
	    }
	    last if(defined $info_ref->[0][0]);
	}
    }
    else {
	$info_ref = $self->{'GetProcessInfo'} -> xSql($process, $group, $purpose, $outputdev);
    }

   if(defined $info_ref->[0][0]) {
	return $info_ref;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find proces step info for group = $group, purpose = $purpose, process = $process, output dev = $outputdev.";
    }	

    return 0;
} #GetProcessInfo




################################
# get Material core user sched #
################################
sub GetUserSchedForPrinting {

    my ($self, $ei_id) = @_;
    
    my $lol = $self->{'GetUserSchedForPrinting'} -> xSql($ei_id);
  
    if(defined $lol->[0][0]) {
	return $lol;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else{
	$Error = "Could not get User $ei_id print list.";
    }	

    return 0;
   
} #GetUserSchedForPrinting
    
	
sub GetBarcodePrefix {

    my ($self, $ps_id) = @_;


    my $prefix = $self->{'GetBarcodePrefix'} -> xSql($ps_id);
    if((defined $prefix)&&($prefix ne '00')) {
	return $prefix;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find prefix for ps_id = $ps_id.";
    }	

    return 0;

} #GetBarcodePrefix


sub GetProcessBarcodeLabel {

    my ($self, $ps_id) = @_;


    my $label = $self->{'GetProcessBarcodeLabel'} -> xSql($ps_id);
    
    if(defined $label) {
	return $label;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find label for ps_id = $ps_id in barcode_outputs table.";
    }	

    return 0;

} #GetProcessBarcodeLabel




#####################################
# Get Process Step Data Output Info #
#####################################
sub GetPsoInfo {
    my ($self, $ps_id, $desc) = @_;


    my $lov = [];
    my $default;
	
    my $pso_id = $self->{'GetPsoId'} -> xSql($ps_id, $desc);

    if(defined $pso_id) {
	
	
    my $pso_lov = $self->{'GetPsoInfo'} -> xSql($pso_id);

	
	foreach my $data (@{$pso_lov}) {
	    
	    push(@{$lov}, $data->[0]);
	    
	    if($data->[1] == 1) {
		$default = $data->[0];
	    }
	}
	
	return($pso_id, $default, $lov);
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find process step data output where ps_id = $ps_id and description = $desc.";
    }	

    return 0;
} #GetPsoInfo


####################################################################
# Count the number of times a barcode has been used in a direction #
####################################################################
sub CountBarcodeUse {

    my ($self, $barcode, $direction) = @_;
   
    my $bar_count = $self->{'CountBarcodeUse'} -> xSql($barcode,$direction);
	
 
    if(defined $bar_count) {
	return ($bar_count);
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not count for barcode = $barcode, direction = $direction.";
    }	

    return -1;


} #CountBarcodeUse

sub GetReageants {

    my ($self, $ps_id) = @_;
    my $reagents = $self->{'GetReageants'} -> xSql($ps_id);

    if(defined $reagents->[0]) {
	return $reagents;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not get reagents from ps_id = $ps_id.";
    }

    return 0;

} #GetReagents

sub GetReagentPurposes {

    my ($self, $ps_id) = @_;

    my $reagents = $self->{'GetReagentPurposes'} -> xSql($ps_id);

    if(defined $reagents->[0]) {
	return $reagents;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not get reagents from ps_id = $ps_id.";
    }

    return 0;

} #GetReagents

sub CheckReagentBarcode {
    
    my ($self, $barcode) = @_;
    my $reagent = $self->{'CheckReagentBarcode'} -> xSql($barcode);
    
    if(defined $reagent) {
	return $reagent;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not get reagent from barcode = $barcode.";
    }

    return 0;



} #CheckReagentBarcode


sub GetProcessReagentInfo {
    
    my ($self, $ps_id, $barcode) = @_;
    my $reagent = $self->{'GetReagentPurpose'} -> xSql($ps_id, $barcode);
    
    if(defined $reagent->[0][0]) {
	return $reagent;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not get reagent from barcode = $barcode.";
    }

    return 0;



} #GetProcessReagentInfo



sub GetMachines {

    my ($self, $ps_id) = @_;
    my $machines = $self->{'GetMachines'} -> xSql($ps_id);
    return $machines;

} #GetMachines

sub GetMachineInfo {

    my ($self, $barcode) = @_;
    my $info = $self->{'GetMachineInfo'} -> xSql($barcode);
    
    if(defined $info->[0][0]) {
	return ($info->[0][0].' - '.$info->[0][1]);
    }

    return 0;
} #GetMachineInfo

sub CheckMachineBarcode {
    
    my ($self, $ps_id, $barcode) = @_;
    
    my $machine = $self->{'CheckMachineBarcode'} -> xSql($ps_id, $barcode);
  
    if(defined $machine->[0][0]) {
	my $mach = $machine->[0][0].' '.$machine->[0][1];
	return $mach;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Not a valid machine barcode = $barcode.";
    }

    return 0;

} #CheckMachineBarcode

sub GetMachineBarcode {
    
    my ($self, $machine, $number) = @_;
    my $barcode = $self->{'GetMachineBarcode'} -> xSql($machine, $number);
    if(defined $barcode) {
	return $barcode;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not get machine barcode from machine = $machine and number = $number.";
    }

    return 0;



} #GetMachineBarcode

sub CheckIfAbandoned {

    my ($self, $barcode) = @_;

    my $count = $self->{'CheckIfAbandoned'} -> xSql($barcode);
    
   
    if($count > 0) {
	return 1;
    }

    return 0;
}

sub CheckPlateType {

    my ($self, $barcodes) = @_;

    my $desc = $self->{'CheckPlateType'} -> xSql($barcodes->[0]);
    
    if($desc =~ /384/) {
	return 384;
    }

    return 0;

} #CheckPlateType



############################################################################################
#                                                                                          #
#                                     BARCODE DESC QUERRIES                                #
#                                                                                          #
############################################################################################


##########################################
# Gets information for barcode prefix 0h #
##########################################
sub Prefix0f {
    
    my ($self, $barcode) = @_;
    
    my $temp = $self->{'Prefix0f'} -> xSql($barcode);
    
    if(defined $temp->[0][0]) {
	my $desc = $temp->[0][0].' lot '.$temp->[0][1].' stock='.$temp->[0][2];
	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;

} #Prefix0f
   
##########################################
# Gets information for barcode prefix 0h #
##########################################
sub PrefixEquip {
    
    my ($self, $barcode) = @_;
    
    my $temp = $self->{'PrefixEquip'} -> xSql($barcode);
    
    if(defined $temp->[0][0]) {
	my $desc = $temp->[0][0].' '.$temp->[0][1];
	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for equipment barcode = $barcode.";
    }	

    return 0;

} #PrefixEquip
   

##########################################
# Gets information for barcode prefix 0h #
##########################################
sub Prefix0g {
    
    my ($self, $barcode) = @_;
    my $temp = $self->{'Prefix0g'} -> xSql($barcode);
    
    if(defined $temp->[0][0]) {
	my $desc = $temp->[0][0].' batch '.$temp->[0][1].' stock='.$temp->[0][2].' avail='.$temp->[0][3];
	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;

} #Prefix0g
   

##########################################
# Gets information for barcode prefix 0h #
##########################################
sub Prefix0h {
    
    my ($self, $barcode) = @_;
    
    my $temp = $self->{'Prefix0h'} -> xSql($barcode);
    
    if(defined $temp->[0][0]) {
	my $desc = $temp->[0][0].' '.$temp->[0][1].' '.$temp->[0][2];
	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;

} #Prefix0h
   
sub PrefixClone {

    my ($self, $barcode) = @_;

    my $clone = $self->{'PrefixClone'} -> xSql($barcode);


    if(defined $clone) {
	return $clone;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;
}
sub PrefixCloneLib {

    my ($self, $barcode) = @_;

    my $lol = $self->{'PrefixCloneLib'} -> xSql($barcode);

    if(defined $lol->[0][0]) {
	my $lib;
	if($#{$lol} == 0) {
	    $lib = $lol->[0][0];
	}
	else {
	    $lib = substr($lol->[0][0], 0, length($lol->[0][0]) - 3);
	}
	return ($lib);
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;
}

sub PrefixCloneGrowthLib {

    my ($self, $barcode) = @_;

    my $lol = $self->{'PrefixCloneGrowthLib'} -> xSql($barcode);

    if(defined $lol->[0][0]) {
	my $lib;
	if($#{$lol} == 0) {
	    $lib = $lol->[0][0];
	}
	else {
	  foreach my $info (@$lol) {
	    if($info->[0] !~ /\s+unknown|\s+none/i) {
	      $lib = $info->[0];
	      last;
	    } 
	  }
	  if(! $lib) {
	    $lib = substr($lol->[0][0], 0, length($lol->[0][0]) - 3);
	  }
	}
	return ($lib);
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;
}

sub PrefixGrowth {

    my ($self, $barcode) = @_;
    
    my $temp = $self->{'PrefixGrowth'} -> xSql($barcode);
    if(defined $temp->[0][0]) {
	my $desc='';
	foreach my $growth (@{$temp}) {
	    $desc = $desc.' '.$growth->[0].$growth->[1];
	}
	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;
}
sub PrefixLibrary {

    my ($self, $barcode) = @_;
    
    my $temp = $self->{'PrefixLibrary'} -> xSql($barcode);
    if(defined $temp->[0][0]) {
	my $desc = $temp->[0][0].' '.$temp->[0][1];
	return $desc;
    }
    else {
	$temp = $self->{'PrefixLibraryFromSubclone'} -> xSql($barcode);
	if(defined $temp->[0][0]) {
	    my $desc = $temp->[0][0].' '.$temp->[0][1];
	    return $desc;
	}
    }
    
    
    $Error = "Could not find information for barcode = $barcode.";


    return 0;
}

sub PrefixFraction {

    my ($self, $barcode) = @_;

    my $temp = $self->{'PrefixFraction'} -> xSql($barcode);
    if(defined $temp->[0][0]) {
	my $desc = $temp->[0][0].' '.$temp->[0][1].' '.$temp->[0][2];
	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;
}


sub PrefixLigation {

    my ($self, $barcode, $direction) = @_;

    $direction = 'out' if(!defined $direction);

    my $temp = $self->{'PrefixLigation'} -> xSql($barcode, $direction);
   if(defined $temp->[0][0]) {
	my $desc = $temp->[0][0].' '.$temp->[0][1].' '.$temp->[0][2];
	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;
}

sub PrefixFractionOrLigation {

    my ($self, $barcode) = @_;

    my $desc = $self->PrefixLigation($barcode, 'in');
    if(!$desc) {
	$desc = $self->PrefixFraction($barcode);
	if($desc) {
	    return $desc;
	}
    }
    else {
	return $desc;
    }
    return 0;
}

sub PrefixGrowthOrLigation {

    my ($self, $barcode) = @_;

    my $desc = $self->PrefixGrowth($barcode);
    if(!$desc) {
	$desc = $self->PrefixLigation($barcode, 'out');
	if($desc) {
	    return $desc;
	}
    }
    else {
	return $desc;
    }
    return 0;
}


sub PrefixSubclone {

    my ($self, $barcode) = @_;
    
    my $temp = $self->{'PrefixSubclone'} -> xSql($barcode);
    if(defined $temp->[0][0]) {
	my @arcs;
	for my $i (0 .. $#{$temp}) {
	    push(@arcs, $temp->[$i][3]);
	}

	my $desc = $temp->[0][0].' '.$temp->[0][1].' '.$temp->[0][2]." @arcs";
	$desc = $desc.'  '.$temp->[0][3] if($temp->[0][3] eq 'qc');
	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;
}

sub PrefixFinSubclone {

    my ($self, $barcode) = @_;
    
    my $temp = $self->{'PrefixFinSubclone'} -> xSql($barcode);
    if(defined $temp->[0][0]) {
	my @arcs;
	for my $i (0 .. $#{$temp}) {
	    push(@arcs, $temp->[$i][2]);
	}

	my $desc = $temp->[0][0].' '.$temp->[0][1]." @arcs";

	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;
}

sub PrefixSequenceOrLib {

    my ($self, $barcode) = @_;

    my $result = $self -> PrefixSequence($barcode);

    if(!$result) {
        $result = $self -> PrefixCloneLib($barcode);
    }

    return $result;
}
sub PrefixSequence {

    my ($self, $barcode) = @_;

    
    my $temp = $self->{'PrefixSequence'} -> xSql($barcode);
   if(! defined  $temp->[0][0]) {

	my $result = $self -> PrefixSubclone($barcode);
	
	if($result) {

	    return $result;
	}
    }

    if(defined $temp->[0][0]) {
	my @arcs;
	for my $i (0 .. $#{$temp}) {
	    push(@arcs, $temp->[$i][2]);
	}

	my $desc = $temp->[0][0].' '.$temp->[0][1]." @arcs";
	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;
}

sub PrefixBarcodeDesc {

    my ($self, $barcode) = @_;

    my $desc = $self->{'GetBarcodeDesc'} -> xSql($barcode);
    if(defined $desc) {
	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find barcode desc for barcode = $barcode.";
    }	

    return 0;
}

sub PrefixGenome {

    my ($self, $barcode) = @_;
    
    my $subclone = $self->{'PrefixGenome'} -> xSql($barcode);
    if(defined $subclone) {
	#my $desc= substr($subclone, 0, 5);
	my ($desc) = $subclone =~ /^(.*)[A-H]\d\d$/;
	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;
}
sub PrefixPrimer {

    my ($self, $barcode) = @_;
    
    my $primer_name = $self->{'PrefixPrimer'} -> xSql($barcode);
    if(defined $primer_name) {

	return $primer_name;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;
}
sub PrefixPcr {

    my ($self, $barcode) = @_;
    
    my $info = $self->{'PrefixPse'} -> xSql($barcode);
    if(defined $info->[0]) { 
	my $desc;
	foreach my $pse (@$info) {
	    my $pcr = $self->{'PrefixPcr'} -> xSql($pse);

	    my @desc_info = $pcr =~ /^(.*)[A-H]\d\dPCR(.*)[a-z](.*)$/;

	    $desc = join "_",@desc_info;

	    #$desc .= substr($pcr, 0, 5).' '.substr($pcr, 8, length($pcr)).'  ';
	}
	return $desc;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find information for barcode = $barcode.";
    }	

    return 0;
}

############################################################################################
#                                                                                          #
#                                     Update Subrotines                                    #
#                                                                                          #
############################################################################################


############################################################################################
#                                                                                          #
#                                     Insert Subrotines                                    #
#                                                                                          #
############################################################################################

#################################################################
# Insert a new record into the pse_equipment_informations table #
# and link to the pse_id                                        #
#################################################################
sub EquipmentEvent {
    
    my ($self, $pse_id, $equipment_id) = @_;
 
    my $result = $self->{'EquipmentEvent'} -> xSql($equipment_id, $pse_id);
    if($result) {
	return $result;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not insert equipment event where pse_id = $pse_id, equinf_bs_barcode = $equipment_id.";
    }	

    return 0;

} #EquipmentEvent

#################################################################
# Insert a new record into the pse_equipment_informations table #
# and link to the pse_id                                        #
#################################################################
sub ReagentEvent {
    
    my ($self, $pse_id, $reagent_barcode) = @_;

    my $result = $self->{'ReagentEvent'} -> xSql($pse_id, $reagent_barcode);
 
    if($result) {
	return $result;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not insert equipment event where pse_id = $pse_id, reagent = $reagent_barcode.";
    }	

    return 0;

} #ReagentEvent


sub InsertPsePsoInfo {

    my ($self, $pse_id, $pso_id, $value) = @_;

 
    my $result = $self->{'InsertPsePsoInfo'} -> xSql($pse_id, $pso_id, $value);

    if($result) {
	return $result;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not insert into pse_data_outputs values ('$pse_id', '$pso_id', '$value') .";
    }	

    return 0;
	
}




#################################################################
#                                                               #
#                    HISTORY QUERRIES                           #
#                                                               #
#################################################################

#################################################
# Get Project Information for a scanned barcode #
#################################################
sub GetProjectInfo {

    my ($self, $barcode) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    
    my $sql = "select distinct pse_pse_id from pse_barcodes pb
               where pb.bs_barcode = '$barcode' and pb.direction = 'out'"; 
    my $orig_pses =  Lquery ($dbh, $sql);
    
    my @project_ids;
    my $project_queries = $self->{'project_queries'};
 
    if(defined $orig_pses->[0]) {
	
	
	foreach my $pse_id (@{$orig_pses}) {
	    my @pse_tables = qw(projects_pses clones_pses clone_growths_pses clone_libraries_pses fractions_pses ligations_pses subclones_pses seq_dna_pses);
	    
	    foreach my $table (@pse_tables) {
		
		my $count =  Query ($dbh, "select count(*) from $table where pse_pse_id = '$pse_id'");
				    
		if($count > 0) {
		    my $project_id = $project_queries -> {$table} -> xSql($pse_id);
		    if(defined $project_id) {
			push(@project_ids, @{$project_id});
		    }
		}
	    }
	}
	
	my @master;
	my ($one, $two, $match);
	
	# Filter out duplicate pses
	foreach my $one (@project_ids) {
	    $match = 0;
	    foreach my $two (@master) {
		
		$match = 1 if ($one == $two) ;
	    }
	    push(@master, $one) if(!$match);
	}
	
	my $project_info = [];
	#'Project', 'Purpose', 'Status', 'Priority', 'Archives', 'Target', 'Qc Status', 'Estimated Size', 'Contigs', 'Assembled Traces', 'Last Assembled'
	# retrieve the information for each pse
	foreach my $project_id (@master) {
	    my $info = $project_queries -> {'project_attributes'} -> xSql($project_id);
	    my $arc_info = $project_queries -> {'project_archives'} -> xSql($project_id);
	    my $qc_info = $project_queries -> {'active_qc'} -> xSql($project_id);

	    
	    $info -> [0][4] = $#{$arc_info}+1;
	    $info -> [0][4] = 0 if($#{$arc_info} == -1);
	    
	    my $qc;
	    foreach my $qc_lig (@{$qc_info}) { 
		my $picked = $project_queries -> {'qc_picked'} -> xSql($qc_lig->[1]);
		$qc = $qc."\n" if(defined $qc);
		if($picked) {
		    $qc = $qc_lig->[0]." - picked";
		}
		else {
		    $qc = $qc_lig->[0]." - not picked";
		}
	    }
	    $info -> [0][6] = $qc;
	    
	    push(@{$project_info}, @{$info});
	}
	if(defined $project_info->[0][0]) {
	    return (1, $project_info);
	}
    }

    $Error = "Could find project information for barcode = $barcode.";

    return 0;
} #GetProjectInfo

#################################################
# Get History Information for a scanned barcode #
#################################################
sub GetCloneHistoryInfo {

    my ($self, $barcode) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    my $proc_evs= [];
    
    my $sql = "select distinct pse_pse_id from pse_barcodes pb
               where pb.bs_barcode = '$barcode' and pb.direction = 'out'"; 
    my $orig_pses =  Lquery ($dbh, $sql);
    my $i=0;
    my $pses = [];
    my $pse_loc = {};
    my @pse_tables = qw(clones  clone_growths);

    my $clone_queries = $self->{'CloneHistoryQueries'};
    
    foreach my $pse_id (@{$orig_pses}) {
	
	my $clo_id = 0;
	
	# find the clone related to the pse which is derived from the barcode
       foreach my $table (@pse_tables) {
    
	    my $tb = $table.'_pses';
	    my $count =  Query ($dbh, "select count(*) from $tb where pse_pse_id = '$pse_id'");
          
	    if($count > 0) {
      	$clo_id = $clone_queries->{$table.'.clo_id'}->xSql($pse_id);
		last;
	    }
	    
	}
 


	if($clo_id) {
	    
	    # find the all the pses related to the clone in each table 
	    foreach my $table (@pse_tables) {
		my $list = $clone_queries->{$table.'.pse_id'}->xSql($clo_id);
		if(defined $list->[0]) {
		    push(@{$pses}, @{$list});
		    foreach my $id (@{$list}) {
			$pse_loc->{$id} = $table;
		    }
		}
	    }
	}

    }
	
    # sort the pses 
    my @pses = sort {$a <=> $b} @{$pses};

    my @master;
    my ($one, $two, $match);

    # Filter out duplicate pses
    foreach my $one (@pses) {
	$match = 0;
	foreach my $two (@master) {

	    $match = 1 if ($one == $two) ;
	}
	push(@master, $one) if(!$match);
    }
    # retrieve the information for each pse
    foreach my $pse (@master) {
	
	
	#'BARCODE INPUT', 'BARCODE OUTPUT', 'CLONE', 'GROWTH EXT', 'PROCESS', 'DATE COMPLETED', 'STATUS', 'RESULT', 'EMPLOYEE CONFIRM', 'SESSION', 'PSE'    
	$proc_evs->[$i][0] = $self -> {'bar_sql'} -> xSql($pse, 'in');
	$proc_evs->[$i][1] = $self -> {'bar_sql'} -> xSql($pse, 'out');

	my $table = $pse_loc->{$pse};
	my $temp_ref = $clone_queries->{$table.'.info'} -> xSql($pse);
	
	my $lib = 1;
	if($#{$temp_ref} == 0) {
	    $temp_ref = $clone_queries -> {'clone_growths_check'} -> xSql($proc_evs->[$i][0]);
	    if($#{$temp_ref} == 0) {
		$lib = 0;
		$proc_evs->[$i][2] = $temp_ref->[0][0];
		$proc_evs->[$i][3] = $temp_ref->[0][1];
	    }
	}

	if($lib) {
	    my @libs;
	    my $growths = [];
	    
	    foreach my $line (@$temp_ref) {
		my $lib = substr($line->[0], 0, length($line->[0]) - 3);
		my @inlist = grep(/^$lib$/, @libs);
		push(@libs, $lib) if($#inlist == -1);
		
		@inlist = grep(/^$line->[1]$/, @$growths);
		push(@{$growths}, $line->[1]) if($#inlist == -1);
	    }
	    
	    $proc_evs->[$i][2] = "@libs";;
	    $proc_evs->[$i][3] = "@$growths";
	}

	$proc_evs->[$i][4] = $self->{'process_to_sql'} -> xSql($pse);
	
	$temp_ref = $self -> {'pse_info'} -> xSql($pse);
	$proc_evs->[$i][5] = $temp_ref->[0][0];
        $proc_evs->[$i][6] = $temp_ref->[0][1];
        $proc_evs->[$i][7] = $temp_ref->[0][2];
	$proc_evs->[$i][9] = $temp_ref->[0][3];

        $proc_evs->[$i][8] = $self -> {'unix_sql'} -> xSql($pse);
	$proc_evs->[$i][10] = $pse;
	
	$i++;
	
    }

    if(@{$proc_evs} > 0) {
	return (1, $proc_evs);
    }
    
    $Error = "Could not find clone history for barcode = $barcode.";
    return(0);
} #GetCloneHistoryInfo

#################################################
# Get History Information for a scanned barcode #
#################################################
sub GetLibraryHistoryInfo {

    my ($self, $barcode) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    my $proc_evs= [];

    my $sql = "select distinct pse_pse_id from pse_barcodes pb
               where pb.bs_barcode = '$barcode' and pb.direction = 'out'"; 
    my $orig_pses =  Lquery ($dbh, $sql);
    my $i=0;
    my $pses = [];
    my $pse_loc = {};
    
    my @pse_tables = qw(clone_libraries fractions ligations);
   
    my $lib_queries =  $self -> {'LibraryQuries'};


    foreach my $pse_id (@{$orig_pses}) {
	my $cl_id = 0;
	
	foreach my $table (@pse_tables) {
	    my $tb = $table.'_pses';
	    my $count =  Query ($dbh, "select count(*) from $tb where pse_pse_id = '$pse_id'");
	    if($count > 0) {
		$cl_id = $lib_queries->{$table.'.cl_id'} -> xSql($pse_id);
		last;
	    }
	    
	}
	if($cl_id) {
	    
	    foreach my $table (@pse_tables) {
		my $list = $lib_queries->{$table.'.pses'} -> xSql($cl_id);
		if(defined $list->[0]) {
		    push(@{$pses}, @{$list});
		    foreach my $id (@{$list}) {
			$pse_loc->{$id} = $table;
		    }
		}
	    }
	}
	
    }
    
    #sort pses
    my @pses = sort {$a <=> $b} @{$pses};
    
    my @master;
    my ($one, $two, $match);
    # remove any duplicates
    foreach my $one (@pses) {
	$match = 0;
	foreach my $two (@master) {

	    $match = 1 if ($one == $two) ;
	}
	push(@master, $one) if(!$match);
    }
    
    
 
    # get information for each pse found related to the library
    foreach my $pse (@master) {
	
	#('BARCODE INPUT', 'BARCODE OUTPUT', 'CLONE', 'GROWTH', 'LIBRARY', 'FRACTION', 'LIGATION', 'PROCESS', 'DATE COMPLETED', 'STATUS', 'EMPLOYEE CONFIRM', 'PSE');
	    
	$proc_evs->[$i][0] = $self->{'bar_sql'} -> xSql($pse, 'in');
	$proc_evs->[$i][1] = $self->{'bar_sql'} -> xSql($pse, 'out');
	
	my $table = $pse_loc->{$pse};
	my $cl_id= $lib_queries->{$table} -> xSql($pse);

	my $temp_ref = $lib_queries -> {'clo_id_sql1'} -> xSql($cl_id);
	
	if(! defined $temp_ref -> [0][0]) {
	    $temp_ref = $lib_queries -> {'clo_id_sql2'} -> xSql($cl_id);
	}

	$proc_evs->[$i][2] = $lib_queries -> {'clone_sql'} -> xSql($temp_ref->[0][0]);
	$proc_evs->[$i][3] = $temp_ref -> [0][1];;

	$proc_evs->[$i][4] ='';
	$proc_evs->[$i][5] ='';
	$proc_evs->[$i][6] = '';

	if($table eq 'clone_libraries') {
	    $proc_evs->[$i][4] = $lib_queries -> {'library_sql'} -> xSql($cl_id);
	}
	
	if($table eq 'fractions') {
	    $temp_ref = $lib_queries -> {'fraction_sql'} -> xSql($cl_id, $pse);
	    $proc_evs->[$i][4] = $temp_ref->[0][0];
	    $proc_evs->[$i][5] = $temp_ref->[0][1];
	}
    
       if($table eq 'ligations') {
	   $temp_ref = $lib_queries -> {'ligation_sql'} -> xSql($pse, $cl_id);
	   $proc_evs->[$i][4] = $temp_ref->[0][0];
	   $proc_evs->[$i][5] = $temp_ref->[0][1];
	   $proc_evs->[$i][6] = $temp_ref->[0][2];
	   
       }
	$proc_evs->[$i][7] = $self -> {'process_to_sql'} -> xSql($pse);

	$temp_ref = $self -> {'pse_info'} -> xSql($pse);
	$proc_evs->[$i][8] = $temp_ref->[0][0];
        $proc_evs->[$i][9] = $temp_ref->[0][1];
        $proc_evs->[$i][10] = $temp_ref->[0][2];

        $proc_evs->[$i][11] = $self -> {'unix_sql'} -> xSql($pse);
	$proc_evs->[$i][12] = $pse;
	
	$i++;
	
    }
    
    if(@{$proc_evs} > 0) {
	return (1, $proc_evs);
    }
    
    $Error = "Could not find library history for barcode = $barcode.";
    return(0);
} #GetLibraryHistoryInfo


#################################################
# Get History Information for a scanned barcode #
#################################################
sub GetArchiveHistoryInfo {

    my ($self, $barcode) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    my $proc_evs= [];
    
    my $sql = "select distinct pse_pse_id from pse_barcodes pb
               where pb.bs_barcode = '$barcode' and pb.direction = 'out'"; 
    my $orig_pses =  Lquery ($dbh, $sql);
    
    if(!defined $orig_pses) {
	$Error = "Barcode is not linked to a plate";
	return(0,0);
    }
    my $i=0;
    my $pses = [];
    my $pse_loc = {};
    my @pse_tables = qw(archives subclones seq_dna traces read_exps);
    
    my $arch_queries = $self->{'ArchiveQueries'};

    foreach my $pse_id (@{$orig_pses}) {
	my $arc_id = 0;
	
	foreach my $table (@pse_tables) {
	    my $tb = $table.'_pses';
	    my $count =  Query ($dbh, "select count(*) from $tb where pse_pse_id = '$pse_id'");
	    if($count > 0) {
		$arc_id = $arch_queries->{$table.'.arc_id'} -> xSql($pse_id);
		last;
	    }
	    
	}
	if($arc_id) {
	    
	    foreach my $table (@pse_tables) {
		my $list = $arch_queries->{$table.'.pse_id'} -> xSql($arc_id);
		if(defined $list->[0]) {
		    push(@{$pses}, @{$list});
		    foreach my $id (@{$list}) {
			$pse_loc->{$id} = $table;
		    }
		}
	    }
	}
	
    }
    # sort pses
    my @pses = sort {$a <=> $b} @{$pses};

    my @master;
    my ($one, $two, $match);
    # filter out duplicates
    foreach my $one (@pses) {
	$match = 0;
	foreach my $two (@master) {

	    $match = 1 if ($one == $two) ;
	}
	push(@master, $one) if(!$match);
    }
    
 
    #('BARCODE INPUT', 'BARCODE OUTPUT', 'CLONE', 'LIBRARY', 'EXT', 'ARCHIVE', 'SECTOR','PURPOSE' , 'PROCESS', 'DATE COMPLETED', 'STATUS', 'EMPLOYEE CONFIRM', 'PSE');

   foreach my $pse (@master) {
	
	$proc_evs->[$i][0] = $self -> {'bar_sql'} -> xSql($pse, 'in');
	$proc_evs->[$i][1] = $self -> {'bar_sql'} -> xSql($pse, 'out');
	
	my $table = $pse_loc->{$pse};
	my $temp_ref = $arch_queries->{$table} -> xSql($pse);
	$proc_evs->[$i][6] = $temp_ref->[0][1];
	
        my $arc_id = $temp_ref->[0][0];

	my $lig_id = $arch_queries->{'lig_id'} -> xSql($arc_id);
	$temp_ref = $arch_queries->{'fra_id'} -> xSql($lig_id);

	$proc_evs->[$i][4] = $temp_ref->[0][1];

	my $cl_id = $arch_queries->{'cl_id'} -> xSql($temp_ref->[0][0]);
	$proc_evs->[$i][3] = $arch_queries->{'library_number'} -> xSql($cl_id);
	my $cg_id = $arch_queries->{'cg_id'} -> xSql($cl_id);
	my $clo_id = $arch_queries->{'clo_id'} -> xSql($cg_id);
	$proc_evs->[$i][2] = $arch_queries->{'clone_name'} -> xSql($clo_id);


#	$temp_ref = $arch_queries -> {'library_ligation_sql'} -> xSql($arc_id);
#	$proc_evs->[$i][3] = $temp_ref->[0][0];
#	$proc_evs->[$i][4] = $temp_ref->[0][1];

#	$proc_evs->[$i][2] = $arch_queries -> {'clone_sql'} -> xSql($temp_ref->[0][2]);

	$temp_ref = $arch_queries -> {'arc_sql'} -> xSql($arc_id);
	$proc_evs->[$i][5] = $temp_ref->[0][0];
	$proc_evs->[$i][7] = $temp_ref->[0][1];

	$proc_evs->[$i][8] = $self -> {'process_to_sql'} -> xSql($pse);
	$temp_ref = $self -> {'pse_info'} -> xSql($pse);
	$proc_evs->[$i][9] = $temp_ref->[0][0];
        $proc_evs->[$i][10] = $temp_ref->[0][1];
        $proc_evs->[$i][11] = $temp_ref->[0][2];
        $proc_evs->[$i][12] = $self -> {'unix_sql'} -> xSql($pse);
	$proc_evs->[$i][13] = $pse;
	
	$i++;
	
    }
    if(@{$proc_evs} > 0) {
	return (1, $proc_evs);
    }
    
    $Error = "Could not find archive history for barcode = $barcode.";
    return(0);
    
}


#######################
# get Barcode History #
#######################
sub GetBarcodeHistory {

    my ($self, $barcode) = @_;
    
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
   #'BARCODE', 'TEST TYPE' 'DIRECTION', 'PROCESS', 'DATE COMPLETED', 'STATUS', 'CONFIRM EMPLOYEE', 'PSE'

    my $pse_info = LoadSql($dbh, "select DATE_COMPLETED, PSESTA_PSE_STATUS, pr_pse_result from process_step_executions 
                                      where pse_id = ?", 'ListOfList');
     my $unix_sql = LoadSql($dbh, "select distinct unix_login from gsc_users where gu_id = 
                                      (select gu_gu_id from employee_infos where ei_id = 
                                      (select ei_ei_id from process_step_executions where pse_id = ?))", 'Single');
    my $process_to_sql = LoadSql($dbh, "select pro_process_to from process_steps where ps_id = 
                                            (select ps_ps_id from process_step_executions where pse_id = ?)", 'Single');
    my $info = $self->{'GetBarcodeHistory'} -> xSql($barcode);

    my $lol=[];
    my $i = 0;
    foreach my $el (@{$info}) {
	my $pse = $el->[0];
	
	$lol->[$i][0] = $barcode;
        my $test_type = GSC::PSE->get($pse)->inherited_property_value('test_type');
        $lol->[$i][1] = $test_type;

	$lol->[$i][2] = $el->[1];
	
	$lol->[$i][3] = $process_to_sql-> xSql($pse);
	my $temp_ref = $pse_info -> xSql($pse);
	$lol->[$i][4] = $temp_ref->[0][0];
        $lol->[$i][5] = $temp_ref->[0][1];
        $lol->[$i][6] = $temp_ref->[0][2];
        $lol->[$i][7] = $unix_sql -> xSql($pse);
	$lol->[$i][8] = $pse;

	$i++;
    }
   
    if(defined $lol->[0][0]) {
	return (1, $lol);
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else{
	$Error = "Could not get barcode history info for barcode = $barcode.";
    }	

    return 0;
   
} #
    
#######################
# get Equipment History #
#######################
sub GetEquipmentHistory {

    my ($self, $barcode) = @_;
    
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
   #'BARCODE', 'DIRECTION', 'PROCESS', 'DATE COMPLETED', 'STATUS', 'CONFIRM EMPLOYEE', 'PSE'

    my $pse_info = LoadSql($dbh, "select DATE_SCHEDULED, PSESTA_PSE_STATUS, pr_pse_result from process_step_executions 
                                      where pse_id = ?", 'ListOfList');
    
    my $unix_sql = LoadSql($dbh, "select distinct unix_login from gsc_users where gu_id = 
                                      (select gu_gu_id from employee_infos where ei_id = 
                                      (select ei_ei_id from process_step_executions where pse_id = ?))", 'Single');
    my $process_to_sql = LoadSql($dbh, "select pro_process_to from process_steps where ps_id = 
                                            (select ps_ps_id from process_step_executions where pse_id = ?)", 'Single');
    my $info = $self->{'GetEquipmentHistory'} -> xSql($barcode);

    #If there is no dna for the equipment, do the equipment check for the pse.
    if(! @$info) {
       $info = $self->{'GetEquipmentHistoryWithoutDNA'} -> xSql($barcode);   
    }

    my $lol=[];
    my $i = 0;
    foreach my $el (@{$info}) {
	my $pse = $el->[0];
	
	$lol->[$i][0] = $barcode . " " . $el->[2];
	$lol->[$i][1] = $el->[1];
	
	$lol->[$i][2] = $process_to_sql-> xSql($pse);
	my $temp_ref = $pse_info -> xSql($pse);
	$lol->[$i][3] = $temp_ref->[0][0];
        $lol->[$i][4] = $temp_ref->[0][1];
        $lol->[$i][5] = $temp_ref->[0][2];
        $lol->[$i][6] = $unix_sql -> xSql($pse);
	$lol->[$i][7] = $pse;

	$i++;
    }
   
    if(defined $lol->[0][0]) {
	return (1, $lol);
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else{
	$Error = "Could not get barcode history info for barcode = $barcode.";
    }	

    return 0;
   
} #
    


#################################################################
# Returns a description of a barcode based on information in DB #
#################################################################
sub GetBarcodeDesc {
    my ($self, $barcode) = @_;

    my $prefix = substr($barcode, 0, 2);
    my $SubName = $TouchScreen::TouchInfo::BARCODE_DESCRIPTION{$prefix};
  
    if(!(defined $SubName)) {
        my $mbar = GSC::Barcode->get(barcode => $barcode);
	unless($mbar) {
	  die "Cannot find the barcode $barcode!";
	}
	my $label = $mbar->resolve_content_description;
	if(defined $label){
	    if($label){ #- non 0
		return (1, [[$barcode.' '.$label]]);
	    }
	    else{
		#- this is a hack because the function set is really too complex to weave through to do it downstream
		$barcode =~ /^(..)/;
		($label) = App::DB->dbh->selectrow_array(qq/select prefix_description from barcode_prefixes where barcode_prefix = ?/, undef, $1);
		die "Error running a barcode prefix query.  Has the table changed?" unless $label;
		return  (1, [[$barcode.' '.$label]]);
	    }
	}

#	$Error = "No method for barcode prefix defined.";
	return (1, [[$barcode.' '.'no description']]);
    }

    my ($desc) = $self -> $SubName($barcode); 
    
    unless($desc){
		#- this is a hack because the function set is really too complex to weave through to do it downstream
		$barcode =~ /^(..)/;
		($desc) = App::DB->dbh->selectrow_array(qq/select prefix_description from barcode_prefixes where barcode_prefix = ?/, undef, $1);
		die "Error running a barcode prefix query.  Has the table changed?" unless $desc;
	    }
    

    $desc = $barcode.' '.$desc;
    
    return (1, [[$desc]]);

} #GetBarcodeDesc


sub GetFreezerInfo {
    
    my ($self, $barcode) = @_;

    my $parent_barcodes = [];
    $parent_barcodes->[0] = $barcode;
    my $found_children = 1;
    my $equip_info = $self->{'GetEquipmentInfo'} -> xSql($barcode);
    my $freezer_info = [];
    my $info_ref = [];
    my $parent_info = {};
    $parent_info -> {'barcode'} = $barcode;
    $parent_info -> {'family'} = $barcode;
    $parent_info -> {'desc'} = $equip_info->[0][1].' '.$equip_info->[0][2];
    $parent_info -> {'status'}  = $equip_info->[0][0],
    $parent_info -> {'children'} = [];
    
    if($parent_info -> {'status'} eq 'occupied') {
	my $lol = $self -> {'GetArcFromBar'} -> xSql($barcode);
	if(defined $lol->[0][0]) {
	    my $barcode = $lol->[0][0];
	    my $prefix = substr($barcode, 0, 2);
	    my $SubName = $TouchScreen::TouchInfo::BARCODE_DESCRIPTION{$prefix};

	    
	    if(defined $SubName) { 
		my $desc = $self -> $SubName($barcode); 
		$parent_info -> {'bar_info'} = $lol->[0][0]." ".$desc;
	    }
            my @desc = $self->GetBarcodeDesc($barcode);
            $parent_info -> {'bar_info'} =  $desc[1]->[0]->[0];
	}
    }
    

    push(@{$freezer_info}, $parent_info);
    push(@{$info_ref}, $parent_info);
    while($found_children) {
	my $temp_info = [];
	
	foreach my $instance  (@{$info_ref}) {
	    my $barcode = $instance->{'barcode'};
		my $children = $self -> {'GetEquipChildren'} -> xSql($barcode);
		if(defined $children->[0]) {
		    foreach my $child (@{$children}) {
			my $equip_info = $self->{'GetEquipmentInfo'} -> xSql($child);
			
			my $info = {};
			$info -> {'barcode'} = $child;
			$info -> {'desc'} = $equip_info->[0][1].' '.$equip_info->[0][2];
			$info -> {'status'} = $equip_info->[0][0];
			$info -> {'family'} = $instance->{'family'}.'.'.$child;
			$info -> {'children'} = [];

			if($info -> {'status'} eq 'occupied') {
			    my $lol = $self -> {'GetArcFromBar'} -> xSql($child);
			    if(defined $lol->[0][0]) {
				my $barcode = $lol->[0][0];
				my $prefix = substr($barcode, 0, 2);
				my $SubName = $TouchScreen::TouchInfo::BARCODE_DESCRIPTION{$prefix};
                                my @desc = $self->GetBarcodeDesc($barcode);
                                $info -> {'bar_info'} =  $desc[1]->[0][0];
			    }
			}
			push(@{$instance -> {'children'}}, $info);
			push(@{$temp_info}, $info);
		    }
		}
		else {
		    $found_children = 0;
		}
	}
	if(($found_children) || (defined $temp_info->[0])) {
	    $info_ref = [];
	    push(@{$info_ref}, @{$temp_info});
	}
    }

    return $freezer_info;

} #GetFreezerInfo


sub GetArc_BarForSlot {

    my ($self, $barcode) = @_;
    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};

    my $sql = " select distinct max(pse_id) from process_step_executions where 
             psesta_pse_status = 'completed' and ps_ps_id in 
             (select ps_id from process_steps
             where PSS_PROCESS_STEP_STATUS = 'active' and 
             pro_process = 'assign archive plate to storage location' and
             pro_process_to = 'assign archive plate to storage location') and
             pse_id in 
             (select pse_pse_id from pse_equipment_informations where equinf_bs_barcode = '$barcode')";
             

    my $pse_id = Query($dbh, $sql);


    $sql = "select distinct bs_barcode from pse_barcodes where pse_pse_id = '$pse_id' and direction = 'in'";
 
    my $arc_bar = Query($dbh, $sql);


    if(defined $arc_bar) {
	return $arc_bar;
    }
    elsif(defined $DBI::errstr){
	$Error = $DBI::errstr;
    }
    else {
	$Error = "Could not find barcode for slot barcodes = $barcode.";
    }	

    return 0;
}	


#############################################################
# Get History Information for a directed sequencing barcode #
#############################################################
sub GetDirectedSeqHistory {

    my ($self, $barcode) = @_;

    my $dbh = $self -> {'dbh'};
    my $schema = $self -> {'Schema'};
    my $proc_evs= [];
    
    
    my $sql = "select distinct pse_pse_id from pse_barcodes pb
               where pb.bs_barcode = '$barcode' and pb.direction = 'out'"; 
    my $orig_pses =  Lquery ($dbh, $sql);
    
    if(!defined $orig_pses) {
	$Error = "Barcode is not linked to a plate";
	return(0,0);
    }

    my $purpose = Query($dbh, qq/select distinct purpose from process_steps, process_step_executions where ps_id = ps_ps_id and pse_id = $orig_pses->[0]/);
    
    if($purpose ne 'Directed Sequencing') {
	$Error = "Barcode is not linked to a Directed Sequencing Step.";
	return(0,0);
    }
   
    my @barcode_history;
    my $rearray_pse=0;
    my $dir_process;
    my $tbar = $barcode;
    
    while(!$rearray_pse) {	
      my $lol = $self -> {'GetPreBarPse'} -> xSql($tbar);
      push(@barcode_history, $tbar);
      if(defined $lol->[0][0]) {
	foreach my $line (@{$lol}) {
	  my $process = $self -> {'CheckProcess'} -> xSql($line->[1]);
	  if(($process eq 'pick targeted subclones') || ($process eq 'create oligo plate')) {
	    $dir_process = $process;
	    $rearray_pse = $line->[1];
	    last;
	  } else {
	    my @info = $self->FindDirectedSeqHistoryRoot($line->[0], \@barcode_history);
	    if(@info && $info[0]) {
	      ($dir_process, $rearray_pse, $tbar) = @info;
	      last;
	    }
	  }
	}
      } else {
	  $dir_process = $self -> {'CheckProcess'} -> xSql($orig_pses->[0]);
	  $rearray_pse = $orig_pses->[0];
      }	
    }
    my $reaction_info;
    if($dir_process eq 'pick targeted subclones') {
	$reaction_info = $self -> {'PrefinishDyeChem'} -> xSql($tbar);
    }
    else {
        $reaction_info = $self -> {'PrefinishDyeChemFromOligo'} -> xSql($tbar);
    }
    
    my $reaction = $reaction_info->[0][0].' '.$reaction_info->[0][4].' '.$reaction_info->[0][5];

    my $order_num = Query($dbh, qq/select distinct data_value
				  from 
				  process_steps, pse_data_outputs pdo, process_step_outputs pso
				  where 
				  ps_id = pso.ps_ps_id and
				  pso_id = pso_pso_id and
				  pdo.pse_pse_id = $rearray_pse and
				  output_description = 'Order Number' and
				  pro_process_to = '$dir_process' and 
				  purpose = 'Directed Sequencing'/);
    
    
    my $i=0;
    my $pses = [];
    my @pse_tables = qw(subclones_pses seq_dna_pses traces_pses read_exps_pses custom_primer_pse);
    my %pse_hash;

    foreach my $bar (@barcode_history) {
	my $pses = Lquery($dbh, qq/select distinct pse_pse_id from pse_barcodes where bs_barcode = '$bar' order by pse_pse_id/);
	next if(!$pses);
	foreach my $pse_id (@{$pses}) {
	    
	    foreach my $tb (@pse_tables) {
		my $count =  Query ($dbh, "select count(*) from $tb where pse_pse_id = '$pse_id'");
		
		$pse_hash{$pse_id} = $count;
		last if($count != 0);
	    }
	}
    }

    # sort pses
    my @pses = sort {$a <=> $b} keys %pse_hash;
 
    #'BARCODE', 'DIRECTION', 'ORDER #', '# of Subclones', 'Reaction Type', 'PROCESS', 'DATE COMPLETED', 'STATUS', 'RESULT', 'EMPLOYEE CONFIRM', 'PSE'
   foreach my $pse (@pses) {
	
	$proc_evs->[$i][0] = $self -> {'bar_sql'} -> xSql($pse, 'in');
	$proc_evs->[$i][1] = $self -> {'bar_sql'} -> xSql($pse, 'out');

	$proc_evs->[$i][2] = $order_num;
	$proc_evs->[$i][3] = $pse_hash{$pse};
	$proc_evs->[$i][4] = $reaction;

	$proc_evs->[$i][5] = $self -> {'process_to_sql'} -> xSql($pse);
	my $temp_ref = $self -> {'pse_info'} -> xSql($pse);
	$proc_evs->[$i][6] = $temp_ref->[0][0];
        $proc_evs->[$i][7] = $temp_ref->[0][1];
        $proc_evs->[$i][8] = $temp_ref->[0][2];
        $proc_evs->[$i][9] = $self -> {'unix_sql'} -> xSql($pse);
	$proc_evs->[$i][10] = $pse;
	
	$i++;
	
    }
    if(@{$proc_evs} > 0) {
	return (1, $proc_evs);
    }
    
    $Error = "Could not find archive history for barcode = $barcode.";
    return(0);
    
}

=head1 FindDirectedSeqHistoryRoot

Find the root of the Directed sequencing history root

=cut
sub FindDirectedSeqHistoryRoot {
    my ($self, $barcode, $history) = @_;
    my $lol = $self->{'GetPreBarPse'}->xSql($barcode);
    if(defined $lol && $lol->[0]) {
      foreach my $line (@{$lol}) {
	my $process = $self->{'CheckProcess'}->xSql($line->[1]);
	if(($process eq 'pick targeted subclones') || ($process eq 'create oligo plate')) {
          push @$history, $barcode if($history);
          return ($process, $line->[1], ($process eq 'pick targeted subclones' ? $barcode : $line->[0]));
	} else {
	  my @info = $self->FindDirectedSeqHistoryRoot($line->[0]);
	  if(@info && $info[0]) {
            push @$history, $line->[0];
	    $info[2] = $line->[0];
	    return @info;
	  }
	}
      }
    } else {
      $self->{'Error'} = "$pkg: GetDirSeqInfo() -> Could not find direct_seq information for barcode = $barcode.";
      return (0);
    }   
}

1;

# $Header$
