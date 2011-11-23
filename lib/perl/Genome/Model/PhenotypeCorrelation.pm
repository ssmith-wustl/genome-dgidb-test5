package Genome::Model::PhenotypeCorrelation;

use strict;
use warnings;
use Genome;

class Genome::Model::PhenotypeCorrelation {
    is => 'Genome::Model',
    doc => "genotype-phenotype correlation of a population group",
    has_param => [
        alignment_strategy => {
            is => "Text",
            is_many => 0,
            doc => "Strategy align sequence reads.",
        },
        snv_detection_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            doc => "Strategy to be used to detect snvs.",
        },
        indel_detection_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            doc => "Strategy to be used to detect indels.",
        },
        sv_detection_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            doc => "Strategy to be used to detect svs.",
        },
        cnv_detection_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            doc => "Strategy to be used to detect cnvs.",
        },
        group_samples_for_genotyping_by => {
            is => "Text",
            is_many => 0,
            is_optional => 1,
            #default_value => 'each',
            valid_values => ['each', 'trio', 'all'],
            doc => "group samples together when genotyping, using this attribute, instead of examining genomes independently (use \"all\" or \"trio\")",
        },
        phenotype_analysis_strategy => {
            is => "Text",
            is_many => 0,
            is_optional =>1,
            valid_values => ['case-control','quantitative'],
            doc => "Strategy to use to look at phenotypes.",
        },
    ],
    has_input => [
        identify_cases_by => { 
            is => 'Text', 
            is_optional => 1,
            doc => 'the expression which matches "case" samples, typically by their attributes' 
        },
        identify_controls_by => { 
            is => 'Text', 
            is_optional => 1,
            doc => 'the expression which matches "control" samples, typically by their attributes' 
        },
    ],
};

sub help_synopsis_for_create_profile {
    my $self = shift;
    return <<"EOS"

  # quantitative

    genome processing-profile create phenotype-correlation \
      --name 'September 2011 Quantitative Population Phenotype Correlation' \
      --alignment-strategy              'instrument_data aligned to reference_sequence_build using bwa 0.5.9 [-q 5] then merged using picard 1.29 then deduplicated using picard 1.29' \
      --snv-detection-strategy          'samtools r599 filtered by snp-filter v1' \
      --indel-detection-strategy        'samtools r599 filtered by indel-filter v1' \
      --group-samples-for-genotyping-by 'race' \            # some (optional) phenotypic trait, or 'trio' or 'all'
      --phenotype-analysis-strategy     'quantitative' \    # or 'case-control'

    genome propulation-group define 'ASMS-cohort-WUTGI-2011' ASMS1 ASMS2 ASMS3 ASMS4

    genome model define phenotype-correlation \
        --name                      'ASMS-v1' \
        --subject                   'ASMS-cohort-WUTGI-2011' \
        --processing-profile        'September 2011 Quantitative Phenotype Correlation' \

  # case-control

    genome processing-profile create phenotype-correlation \
      --name 'September 2011 Case-Control Population Phenotype Correlation' \
      --alignment-strategy              'instrument_data aligned to reference_sequence_build using bwa 0.5.9 [-q 5] then merged using picard 1.29 then deduplicated using picard 1.29' \
      --snv-detection-strategy          'samtools r599 filtered by snp-filter v1' \
      --indel-detection-strategy        'samtools r599 filtered by indel-filter v1' \
      --group-samples-for-genotyping-by 'trio', \
      --phenotype-analysis-strategy     'case-control'

    genome propulation-group define 'Ceft-Lip-cohort-WUTGI-2011' CL001 CL002 CL003

    genome model define phenotype-correlation \
        --name                  'Cleft-Lip-v1' \
        --subject               'Cleft-Lip-cohort-WUTGI-2011' \
        --processing-profile    'September 2011 Case-Control Phenotype Correlation' \
        --identify-cases-by     'some_nomenclature.has_cleft_lip = "yes"' \
        --identify-controls-by  'some_nomenclature.has_cleft_lip = "no"' \

    # If you leave off the subject, it would find all patients matching the case/control logic
    # and make a population group called ASMS-v1-cohort automatically???


EOS
}

sub help_detail_for_create_profile {
    return <<EOS
  For a detailed explanation of how to write an alignmen strategy see:
    TBD

  For a detailed explanation of how to write a variant detection strategy, see:
    perldoc Genome::Model::Tools::DetectVariants2::Strategy;

  All builds will have a combined vcf in their variant detection directory.

EOS
}

sub help_manual_for_create_profile {
    return <<EOS
  Manual page content for this pipeline goes here.
EOS
}

sub __profile_errors__ {
    my $self = shift;
    my @errors;
    if ($self->alignment_strategy) {
        #my $strat = Genome::Model::Tools::DetectVariants2::Strategy->get($bx->value_for('alignment_strategy'));
        #push @errors, $strat->__errors__;
        #$strat->delete;
    }
    for my $strategy ('snv','indel','sv','cnv') {
        my $method_name = $strategy . '_detection_strategy';
        if (my $strategy_text = $self->$method_name) {
            my $strat = Genome::Model::Tools::DetectVariants2::Strategy->get($strategy_text);
            push @errors,
                map {
                    UR::Object::Tag->create(
                        type => 'invalid',
                        properties => [$method_name],
                        desc => $_
                    )
                }
                $strat->__errors__;
        }
    }
    return @errors;
}

sub _execute_build {
    my ($self,$build) = @_;

    # TODO: remove this and replace with the workflow logic at the bottom when we have one.
    # Version 1 of this pipeline will run in a linear way only if the underlying samples have already
    # had independent alignment and variant detection completed in other models.

    warn "The logic for building this is not yet in place!  The following is initial data gathering...";

    #
    # get the subject (population group), the individual members and their samples
    #

    my $population_group = $build->model->subject;
    $build->status_message("subject is " . $population_group->__display_name__);

    my @patients = $population_group->members();
    $build->status_message("found " . scalar(@patients) . " patients");

    my @samples = $population_group->samples;
    $build->status_message("found " . scalar(@samples) . " samples");

    my @instdata_assn = $build->inputs(name => 'instrument_data');
    $build->status_message("found " . scalar(@instdata_assn) . " assignments for the current build");

    my @instdata = Genome::InstrumentData->get(id => [ map { $_->value_id } @instdata_assn ]);
    $build->status_message("found " . scalar(@instdata) . " instdata");

    #
    # get the reference sequence
    #

    my $reference_sequence_build = $build->inputs(name => 'reference_sequence_build')->value;
    $build->status_message("reference sequence build: " . $reference_sequence_build->__display_name__);
    
    my $reference_fasta = $reference_sequence_build->full_consensus_path('fa');
    unless(-e $reference_fasta){
        die $self->error_message("fasta file for reference build doesn't exist!");
    }
    $build->status_message("reference sequence fasta: " . $reference_fasta);

    #
    # get the bam for each sample
    # this will only work right now if the per-sample model has already run
    # once Tom's new alignment thing is in place, it would actually generate them in parallel
    #
    
    $self->status_message('Gathering alignments...');
    my $result = Genome::InstrumentData::Composite->get_or_create(
        inputs => {
            instrument_data => \@instdata,
            reference_sequence_build => $reference_sequence_build,
        },
        strategy => $self->alignment_strategy,
        log_directory => $build->log_directory,
    );
    my @results = $result->_merged_results;
    for my $r (@results) {
        $r->add_user(label => 'uses', user => $build);
    }

    my @bams = $result->bam_paths;
    unless (@bams == @samples) {
        die $self->error_message("Failed to find alignment results for all samples!");
    }
    $self->status_message('Found ' . scalar(@bams) . ' merged BAMs.');
    for my $bam (@bams){
        unless (-e $bam){
            die $self->error_message("Bam file could not be reached at: ".$bam);
        }
    }

    #
    # run the DV2 API to do variant detection as we do in somatic, but let it take in N BAMs
    # _internally_ it will (for the first pass):
    #  notice it's running on multiple BAMs
    #  get the single-BAM results
    #  merge them with joinx and make a combined VCF (tolerating the fact that per-bam variants are not VCF)
    #  run bamreadcount to fill-in the blanks
    #

    $self->status_message("Executing detect variants step");

    my %params;
    $params{snv_detection_strategy} = $self->snv_detection_strategy if $self->snv_detection_strategy;
    $params{indel_detection_strategy} = $self->indel_detection_strategy if $self->indel_detection_strategy;
    $params{sv_detection_strategy} = $self->sv_detection_strategy if $self->sv_detection_strategy;
    $params{cnv_detection_strategy} = $self->cnv_detection_strategy if $self->cnv_detection_strategy;
    $params{reference_build_id} = $reference_sequence_build->id;
    $params{multiple_bams} = \@bams;

    my $output_dir = $build->data_directory."/variants";
    $params{output_directory} = $output_dir;
    my $dispatcher_cmd = Genome::Model::Tools::DetectVariants2::Dispatcher->create(%params); 
    eval { $dispatcher_cmd->execute };
    if ($@) {
        $self->warning_message("Failed to execute detect variants with multiple BAMs!\n");
        #die $self->warning_message("Failed to execute detect variants dispatcher(err:$@) with params:\n" . Data::Dumper::Dumper \%params);
    }
    else {
        $self->status_message("detect variants command completed successfully");
        my @results = $dispatcher_cmd->results;
        for my $result (@results) {
            $result->add_user(user => $build, label => 'uses');
        }
    }

    # dump pedigree data into a file

    # dump clinical data into a file

    # we'll figure out what to do about the analysis_strategy next...

=cut

if ($self->phenotype-analysis-strategy eq 'case-control') { #unrelated individuals, case-control -- MRSA


# assume that the vcf is passed in as $multisample_vcf

#change vcf -> maf here, which also needs annotation files
#make $maf_file -- might need one with everything and one that doesnt have silent variants in it
my $vcf_line = `grep -v "##" $multisample_vcf | head -n 1`;
chomp($vcf_line);
my ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format, @sample_names) = split(/\t/, $vcf_line);


my $vcf_split_cmd = "gmt vcf vcf-split-samples --vcf-input $multisample_vcf --output-dir $single_sample_dir";

my $maf_header;
my $maf_maker_cmd = "";
foreach $sample_id (@sample_names) {
    my $annotation_file_per_sample = ""; #needs to get some sort of single-sample annotation file from the build or maybe there is a unified annotation file to use?
    my $vcf_cmd = "gmt vcf convert maf vcf-2-maf --vcf-file $single_sample_dir/$sample_id.vcf --annotation-file $annotation_file_per_sample --output-file $single_sample_dir/$sample_id.maf";
system($vcf_cmd);
    $maf_maker_cmd .= " $single_sample_dir/$sample_id.maf";    
}
my $maf_sample_id = $sample_names[0];
$maf_maker_cmd .= " | grep -v \"Hugo_Symbol\" > $single_sample_dir/All_Samples_noheader.maf";
my $final_maf_maker_cmd = "head -n1 $single_sample_dir/$maf_sample_id.maf | cat - $single_sample_dir/All_Samples_noheader.maf > $single_sample_dir/All_Samples.maf";

system($final_maf_maker_cmd);

#start workflow to find significantly mutated genes in our set:
    #get list of bams and load into tmp file named $bam_list
    #for exome set $target_region_set_name_bedfile to be all exons including splice sites, these files are maintained by cyriac
    #not sure how to define $output_dir but in a workflow context this just needs to be a clean folder. Perhaps in the model build context this would be ...model/build/music/bmr/
    my $bmr_cmd = "gmt music bmr calc-covg --bam-list $bam_list --output-dir $output_dir --reference-sequence $reference_fasta --roi-file $target_region_set_name_bedfile --cmd-prefix bsub --cmd-list-file $temp_file";

    #Submitted all the jobs in cmd_list_file to LSF:
    my $submit_cmd = "bash $temp_file";

#need to wait for the above to be done......

    #After the parallelized commands are all done, merged the individual results using the same tool that generated the commands: - MUST KNOW ABOVE STEP IS COMPLETE
    my $bmr_step2_cmd = "gmt music bmr calc-covg --bam-list $bam_list --output-dir $output_dir --reference-sequence $reference_fasta --roi-file $target_region_set_name_bedfile";

    #Calculated mutation rates:
    my $bmr_step3_cmd = "gmt music bmr calc-bmr --bam-list $bam_list --output-dir $output_dir --reference-sequence $reference_fasta --roi-file $target_region_set_name_bedfile --maf-file $maf_file --show-skipped"; #show skipped doesn't work in workflow context

    #Ran SMG test:
    #The smg test limits its --output-file to a --max-fdr cutoff. A full list of genes is always stored separately next to the output with prefix "_detailed".
    my $fdr_cutoff = 0.2; #0.2 is the default -- For every gene, if the FDR for at least 2 of theses test are less than $fdr_cutoff, it is considered as an SMG.
    my $smg_cmd = "gmt music smg --gene-mr-file $output_dir/gene_mrs --output-file $output_dir/smgs --max-fdr $fdr_cutoff";

    my $smg_maf_cmd = "gmt capture restrict-maf-to-smgs --maf-file $maf_file --output-file $output_dir/smg_restricted_maf.maf --output-bed-smgs $output_dir/smg_restricted_bed.bed --smg-file $output_dir/smgs";

#get some pathway information, not used now but we could technically choose to run only genes from certain pathways
    #Ran PathScan on the KEGG DB (Larger DBs take longer):
    #get KEGG DB FILE $kegg_db
    my $pathscan_cmd = "gmt music path-scan --bam-list $bam_list --gene-covg-dir $output_dir/gene_covgs/ --maf-file $maf_file --output-file $output_dir/sm_pathways_kegg --pathway-file $kegg_db --bmr 8.9E-07 --min-mut-genes-per-path 2";

    #Ran COSMIC-OMIM tool:
    my $cosmic_cmd = "gmt music cosmic-omim --maf-file $maf_file --output-file $maf_file.cosmic_omim";

    #Ran Pfam tool:
    my $pfam_cmd = "gmt music pfam --maf-file $maf_file --output-file $maf_file.pfam";

    #Ran Proximity tool:
    my $proximity_cmd = "gmt music proximity --maf-file $maf_file --reference-sequence $reference_fasta --output-file $output_dir/variant_proximity";

    #Ran mutation-relation:
    my $permutations = 1000; #the default is 100, but cyriac and yanwen used either 1000 or 10000. Not sure of the reasoning behind those choices.
    my $mutrel_cmd = "gmt music mutation-relation --bam-list $bam_list --maf-file $maf_file --output-file $output_dir/mutation_relations.csv --permutations $permutations --gene-list $output_dir/smgs"; #number of permutations can be a variable or something

#instead of pathways, use smg test to limit maf file input into mutation relations $maf_file_smg -- no script for this step yet
#The FDR filtered SMG list can be used as input to "gmt music mutation-relation" thru --gene-list, so it limits its tests to SMGs only. No need to make a new MAF. Something similar could be implemented for clinical-correlation.

#Ran clinical-correlation:
#need clinical data file $clinical_data
#example: /gscmnt/sata809/info/medseq/MRSA/analysis/Sureselect_49_Exomes_Germline/music/input/sample_phenotypes2.csv
#this is not the logistic regression yet, found out that yyou and ckandoth did not put logit into music, but just into the R package that music runs
    my $clin_corr = "gmt music clinical-correlation --genetic-data-type gene --bam-list $bam_list --maf-file $output_dir/smg_restricted_maf.maf --output-file $output_dir/clin_corr_result --categorical-clinical-data-file $clinical_data";

#instead of clinical correlation, we can call these stats directly

    #break up clinical data into two files, one for explanatory variable and one for covariates
    #sample_infection.csv = $expl_file
    #Sample_Name	Levels of Infection Invasiveness (0=control, 1=case)
    #H_MRS-6305-1025125	0
    #H_MRS-6401-1025123	1

    #sample_phenotypes.csv = $pheno_file
    #Sample_Name	Age at Time of Infection (years)	Race (1 white 2 black 3 asian)	Gender (1 male 2 female)
    #H_MRS-6305-1025125	10	1	1
    #H_MRS-6401-1025123	16	1	1

    #make smg bed file STILL UNDONE


    my $variant_matrix_cmd = "gmt vcf vcf-to-variant-matrix --output-file $output_dir/variant_matrix.txt --vcf-file $multisample_vcf --bed-roi-file $output_dir/smg_restricted_bed.bed";

    #make .R file example
        ## Build temp file for extra positions to highlight ##
        my ($tfh,$temp_path) = Genome::Sys->create_temp_file;
        unless($tfh) {
            $self->error_message("Unable to create temporary file $!");
            die;
        }
        $temp_path =~ s/\:/\\\:/g;
        my $R_command = <<"_END_OF_R_";
    options(error=recover)
    source("stat.lib", chdir=TRUE)
    #this should work, but I havent tested using the .csv out of mut rel -- wschierd
    mut.file="$output_dir/variant_matrix.txt" 
    inf.file="$expl_file";
    pheno.file="$pheno_file";
    output.file="$output_dir/logit_out_cor.csv";
    #to do logistic regression, might need /gscuser/yyou/git/genome/lib/perl/Genome/Model/Tools/Music/stat.lib.R -- talk to Cyriac here
    cor2test(y=inf.file, x=mut.file, cov=pheno.file, outf=output.file, method="logit", sep="\t");
    _END_OF_R_
        print $tfh "$R_command\n";

        my $cmd = "R --vanilla --slave \< $temp_path";
        my $return = Genome::Sys->shellcmd(
            cmd => "$cmd",
        );
        unless($return) { 
            $self->error_message("Failed to execute: Returned $return");
            die $self->error_message;
        }

=cut

    return 1;
}

sub _validate_build {
    # this is where we sanity check things like inputs making sense before actually building
    my $self = shift;
    my $dir = $self->data_directory;

    my @errors;
    unless (1) {
        my $e = $self->error_message("Something is wrong!");
        push @errors, $e;
    }

    if (@errors) {
        return;
    }
    else {
        return 1;
    }
}

1;

__END__

# TODO: replace the above _execute_build with an actual workflow

sub _resolve_workflow_for_build {
    my $self = shift;
    my $build = shift;

    my $operation = Workflow::Operation->create_from_xml(__FILE__ . '.xml');

    my $log_directory = $build->log_directory;
    $operation->log_dir($log_directory);

    #I think this ideally should be handled
    $operation->name($build->workflow_name);

    return $operation;
}

sub _map_workflow_inputs {
    my $self = shift;
    my $build = shift;

    my @inputs = ();

    #### This is old code from the somatic variation pipeline, replace with phenotype correlation params/inputs! #####

    # Verify the somatic model
    my $model = $build->model;

    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        die $self->error_message;
    }

    my $tumor_build = $build->tumor_build;
    my $normal_build = $build->normal_build;

    unless ($tumor_build) {
        $self->error_message("Failed to get a tumor_build associated with this somatic capture build!");
        die $self->error_message;
    }

    unless ($normal_build) {
        $self->error_message("Failed to get a normal_build associated with this somatic capture build!");
        die $self->error_message;
    }

    my $data_directory = $build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
        die $self->error_message;
    }

    my $tumor_bam = $tumor_build->whole_rmdup_bam_file;
    unless (-e $tumor_bam) {
        $self->error_message("Tumor bam file $tumor_bam does not exist!");
        die $self->error_message;
    }

    my $normal_bam = $normal_build->whole_rmdup_bam_file;
    unless (-e $normal_bam) {
        $self->error_message("Normal bam file $normal_bam does not exist!");
        die $self->error_message;
    }

    push @inputs, build_id => $build->id;

    return @inputs;
}

1;
