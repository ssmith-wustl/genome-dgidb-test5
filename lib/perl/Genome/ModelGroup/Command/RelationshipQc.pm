package Genome::ModelGroup::Command::RelationshipQc;

use strict;
use warnings;
use File::Basename;
use Genome;

class Genome::ModelGroup::Command::RelationshipQc {
    is => 'Genome::Command::Base',
    has => [
    model_group => {
        is => 'Genome::ModelGroup',
        is_optional=>0,
        doc => 'this is the model group you wish to QC',
    },
    output_dir => {
        is => 'Text',
        is_optional=>0,
        doc => 'the directory where you want results stored',
    },
    min_coverage => {
        is => 'Number', 
        is_optional=>1,
        default=>20,
        doc => 'the minimum coverage needed at a site to include it in the IBD analysis',
    },
    snv_bed => {
        is => 'Text',
        is_optional =>'1',
        doc=>'the default it to use any site detected as a snp and passing snp filter, but you can supply your own list of sites if you prefer',
    },

    ],
    has_optional => {
    },
    doc => 'run fastIBD' 
};

sub help_synopsis {
    return <<EOS
genome model-group relationship-qc --model-group=1745 --output-dir=/foo/bar/

EOS
}


sub execute {
    my $self=shift;
    my $model_group  = $self->model_group;
    my $output_dir = Genome::Sys->create_directory($self->output_dir);
    unless($output_dir) {
        $self->error_message("Unable to create output directory: " . $self->output_dir);
        return;
    }
    my @sorted_models = sort {$a->subject_name cmp $b->subject_name} $model_group->models;
    #TODO: verify all succeeded
    my $bed_file;
    if($self->snv_bed) {
        $bed_file = $self->snv_bed;
    }
    else {
        $bed_file = $self->assemble_list_of_snvs(\@sorted_models);
    }
#    my $pileup_file = "/gscmnt/sata921/info/medseq/test_mg_ibd_tool/RP-Family-RFS034.vcf.gz"; 
    my $pileup_file = $self->run_mpileup(\@sorted_models, $bed_file);
    unless($pileup_file) {
        return;
    }

    my $beagle_input = $self->convert_mpileup_to_beagle($pileup_file, $self->min_coverage);
    my $beagle_output = $self->run_beagle($beagle_input);
    $self->generate_relationship_table($beagle_output, $beagle_input);
    return 1;
    #TODO:$self->generate_ibd_per_patient($output_dir);

}

sub assemble_list_of_snvs {
    my $self=shift;
    my $models_ref = shift;
    my %snvs;
    my @snp_files = map {$_->last_succeeded_build->filtered_snvs_bed("v2") } @{$models_ref};
    for my $snp_file (@snp_files) {
        my $snp_fh = Genome::Sys->open_file_for_reading($snp_file);
        while(my $line = $snp_fh->getline) {
            chomp($line);
            my ($chr, $start, $stop, $ref_var) = split "\t", $line;
            $snvs{$chr}{$stop}=1;
        }
        $snp_fh->close;
    }
    #TODO: move output shit up into the class def
    my $output_snvs = $self->output_dir . "/" . $self->model_group->name . ".union.bed";
    my $union_snv_fh = Genome::Sys->open_file_for_writing($output_snvs);
    for my $chr (sort keys %snvs) {
        for my $pos (sort keys %{$snvs{$chr}}) {
            my $start = $pos -1;
            my $stop = $pos;
            $union_snv_fh->print("$chr\t$start\t$stop\n");
        }
    }
    $union_snv_fh->close;
    return $output_snvs;
}

sub run_mpileup {
    my $self=shift;
    my $models_ref = shift;
    my $bed_file = shift;
    my @bams = map {$_->last_succeeded_build->whole_rmdup_bam_file} @{$models_ref};
    my $ref = $models_ref->[0]->reference_sequence_build->full_consensus_path("fa");
    #TODO: move output filenames into class def
    my $output_vcf_gz = $self->output_dir . "/" . $self->model_group->name . ".vcf.gz";
   #samtools mpileup<BAMS>  -uf<REF>   -Dl<SITES.BED>  | bcftools view -g - | bgzip -c>  <YOUR GZIPPED VCF-LIKE OUTPUT> 
    my $cmd = "samtools mpileup @bams -uf $ref -Dl $bed_file | bcftools view -g - | bgzip -c > $output_vcf_gz";
    my $rv = Genome::Sys->shellcmd( cmd => $cmd, input_files => [$bed_file, $ref, @bams]);
    if($rv != 1) {
        return;
    }
    return $output_vcf_gz;
}

sub convert_mpileup_to_beagle {
    my $self = shift;
    my $pileup_vcf_gz = shift;
    my $min_depth=shift;
    #TODO: move output files into class def

    my $output_bgl_file = $self->output_dir . "/" . $self->model_group->name . ".bgl.input";
    my $output_fh = Genome::Sys->open_file_for_writing($output_bgl_file);
    my $vcf_fh = IO::File->new("zcat $pileup_vcf_gz|");
    my @header;
    my $line;
    while($line = $vcf_fh->getline) {
        if($line =~m/^#/) {
            if($line =~m/^#CHROM/) {
                chomp($line);
                @header = split "\t", $line;
                last;
            }
        }
    }
##print header
    $output_fh->print("I\tID");
    splice(@header,0,9);
    for my $sample_name (@header) {
        $output_fh->print("\t$sample_name\t$sample_name");
    }
    $output_fh->print("\n");
    
    while($line= $vcf_fh->getline) {
        my $enough_depth=1;
        next if ($line =~m/INDEL/);

        chomp($line);
        my @fields = split "\t", $line;
        my $chr = $fields[0];
        my $pos = $fields[1];
        my $ref = $fields[3];
        my $alt = $fields[4];
        my $format = $fields[8];
        next if ($format !~ m/GT/);
        my @alts = split ",", $alt;
        unshift @alts, $ref;
        my @output_line =  ("M", "$chr:$pos");

        for (my $i =9; $i < scalar(@fields); $i++) {
            my $sample_field =  $fields[$i];
            my ($gt, $pl, $dp, $gq) = split ":", $sample_field;
            if($dp < $min_depth) {
                $enough_depth=0;
                last;
            }
            my ($all1, $all2)= split /[\/|]/, $gt;
            my $allele1 = $alts[$all1];
            my $allele2 = $alts[$all2];
            push @output_line, ($allele1, $allele2);
        }
        if($enough_depth) {
            $output_fh->print(join("\t", @output_line) . "\n");
        }
    }
    $output_fh->close();
    return $output_bgl_file;
}

sub run_beagle { 
    my $self = shift;
    my $beagle_input = shift;
    my $output_dir = $self->output_dir;
  
    #./beagle.sh  fastibd=true unphased=cleft_lip/mpileup/bgl_from_vcf.test_input out=cleft_lip/mpileup/cleft_lip.out missing=?
    my $cmd = "java -Xmx14000m -jar /gsc/pkg/bio/beagle/installed/beagle.jar fastibd=true unphased=$beagle_input out=$output_dir/beagle missing=?";
    my $rv = Genome::Sys->shellcmd(cmd=>$cmd, input_files=>[$beagle_input]);
    if($rv != 1) {
        $self->error_message("Error running Beagle\n");
        return;
    }
    my ($file, $dir) = fileparse($beagle_input);
    return $dir . "beagle." . $file . ".fibd.gz";
}

sub generate_relationship_table {
    my $self = shift;
    my $beagle_output = shift;
    my $fibd_file = Genome::Sys->open_gzip_file_for_reading($beagle_output);
    my $markers_file = shift;
    #TODO: make output files all in class def
    my $output_file = $self->output_dir . "/relationship_matrix.tsv";
    my $output_fh = Genome::Sys->open_file_for_writing($output_file);
    my $total_markers = `wc -l $markers_file`;
    $total_markers--; #account for header;
    my %relationships;
    while(my $line = $fibd_file->getline) {
        chomp($line);
        my ($first_guy, $second_guy, $start_marker, $stop_marker, $conf) = split "\t", $line;
        my $total_markers_covered;
        if(exists($relationships{$first_guy}{$second_guy})) {
            $total_markers_covered = $relationships{$first_guy}{$second_guy};
        }
        $total_markers_covered += ($stop_marker - $start_marker);
        $relationships{$first_guy}{$second_guy} = $total_markers_covered;
    }
    my $i=0;
    my %table_hash;
    my @table;
    my @header_row;
    $output_fh->print("INDIVIDUAL");
    for my $first_guy (sort keys %relationships) {
        $table_hash{$first_guy}=$i;
        $i++; 
        $output_fh->print("\t$first_guy");
        push @header_row, $first_guy;
    }
    for my $first_guy (sort keys %relationships) {
        for my $second_guy (sort keys %{$relationships{$first_guy}}) {
            unless(grep{/$second_guy/} @header_row) {
                $table_hash{$second_guy}=$i;
                $i++;
                $output_fh->print("\t$second_guy");
                push @header_row, $second_guy;
            }
        }
    }
    $output_fh->print("\n");



    for my $first_guy (sort keys %relationships) {
        for my $second_guy (sort keys %{$relationships{$first_guy}}) {
            my $total_shared_markers = $relationships{$first_guy}{$second_guy};
            my $percent = sprintf("%0.2f", $total_shared_markers/$total_markers * 100);
            my $j = $table_hash{$first_guy};
            my $k = $table_hash{$second_guy};
            $table[$j][$k]=$percent || 0;
        }
    }
    for (my $j=0; $j < $i; $j++) {
        my $person_for_row = $header_row[$j];
        $output_fh->print("$person_for_row");
        for (my $k=0; $k < $i; $k++) {
            my $value = $table[$j][$k] || "N/A";
            $output_fh->print("\t$value");
        }
        $output_fh->print("\n");
    }
    $output_fh->close();
    return 1;
}

    1;
