package Genome::Model::Tools::DetectVariants2::Filter::PolymuttDenovo;

use strict;
use warnings;
use Data::Dumper;
use Genome;
use Genome::Info::IUB;
use POSIX;
use Cwd;
use File::Basename;
use File::Path;

class Genome::Model::Tools::DetectVariants2::Filter::PolymuttDenovo {
    is => 'Genome::Model::Tools::DetectVariants2::Filter',
    has_optional_input => [
    min_read_qual=> {
        doc=>'the lowest quality reads to use in the calculation. default q20',
        default=>"20",
    },
    min_unaffected_pvalue=> {
        doc=>"the minimum binomial test result from unaffected members to pass through the filter",
        default=>"1.0e-4",
    },
    ],
    doc => "A binomial filter for polymutt denovo output",
};

sub help_detail {
    "A binomial filter for polymutt denovo output"
}

sub _variant_type { 'snvs' };

sub _filter_name { 'PolymuttDenovo' };

sub _filter_variants {
    my $self=shift;
    my $vcf = $self->input_directory . "/snvs.denovo.vcf.gz"; # TODO this should probably just operate on snvs.vcf.gz and only filter denovo sites (info field?)
    my $output_file = $self->_temp_staging_directory. "/snvs.vcf.gz";

    my $sites_file = Genome::Sys->create_temp_file_path();
    my $cat_cmd = "cat";
    my $vcf_fh;
    if(Genome::Sys->_file_type($vcf) eq 'gzip') {
        $vcf_fh = Genome::Sys->open_gzip_file_for_reading($vcf);
        $cat_cmd = "zcat";
    }
    else {
        $vcf_fh = Genome::Sys->open_file_for_reading($vcf);
    }

    my $sites_cmd = qq/ $cat_cmd $vcf | cut -f1,2 | grep -v "^#" | awk '{OFS="\t"}{print \$1, \$2, \$2}' > $sites_file/;

    unless(-s $sites_file) {
        print STDERR "running $sites_cmd\n";
        `$sites_cmd`;
    }

    # Sort the alignment results in a sane way
    my $header_cmd = qq/ $cat_cmd $vcf | grep "^#CHR"/;
    my $header_line= `$header_cmd`;
    unless ($header_line) {
        die $self->error_message("Could not get the header line with subject names using $header_cmd");
    }
    #my @previous_alignment_result_ids = $self->previous_result->alignment_results;
    #my @previous_alignment_results = Genome::InstrumentData::AlignmentResult::Merged->get(\@previous_alignment_result_ids);
    #my @alignment_results = $self->sort_alignment_results_by_header($header_line, @previous_alignment_results);
    my @alignment_results = $self->sort_alignment_results_by_header($header_line, $self->alignment_results);

###prepare readcounts
    my $ref_fasta=$self->reference_sequence_input;
    my $readcount_file_ref = $self->prepare_readcount_files($ref_fasta, $sites_file, \@alignment_results);
    my $r_input_path = $self->prepare_r_input($vcf_fh, $readcount_file_ref);
    my ($r_fh, $r_script_path) = Genome::Sys->create_temp_file();
    my ($r_output) = Genome::Sys->create_temp_file_path();
    $r_fh->print($self->r_code($r_input_path, $r_output));
    $r_fh->close;
    `R --vanilla < $r_script_path`;
    my $unaffecteds = $self->find_indexes_of_unaffecteds($header_line, $self->pedigree_file_path);
    $self->output_passing_vcf($vcf, $r_output, $self->min_unaffected_pvalue, $output_file, $unaffecteds);
    return 1;
}

sub find_indexes_of_unaffecteds {
    my ($self, $header_line, $ped_file) = @_;
    my $ped_fh = IO::File->new($ped_file);
    my @unaffected_indices;
    my %status;
    while(my $line = $ped_fh->getline) {
        chomp($line);
        my @fields = split "\t", $line;
        my $sample_name = $fields[1];
        my $affectation_status = $fields[-1];
        if(($affectation_status ne 'U') && ($affectation_status ne 'A')) {
            $self->error_message("Ped line: $line does not end in U or A. Unable to parse ped to figure out who is unaffected.");
            die;
        }
        $status{$sample_name}=$affectation_status;
    }
    $ped_fh->close();
    my @header = split"\t", $header_line;
    splice(@header, 0, 9);
    for(my $i = 0; $i < scalar(@header); $i++) {
        if(exists($status{$header[$i]})) {
            if($status{$header[$i]} eq 'U') {
                push @unaffected_indices, $i;
            }
        }
    }
    return \@unaffected_indices;
}

sub output_passing_vcf {
    my($self, $input_filename, $r_output, $pvalue_cutoff, $output_filename, $unaffecteds) = @_;
    my $pvalues = Genome::Sys->open_file_for_reading($r_output);
    my $input_file = Genome::Sys->open_gzip_file_for_reading($input_filename);
    my $output_file = Genome::Sys->open_gzip_file_for_writing($output_filename);
    my $filter_name = $self->_filter_name;

    my $input_line = $input_file->getline;
    while ($input_line =~ /^#/) {
        $output_file->print($input_line);
        $input_line = $input_file->getline;
    }
    my ($vcf_chr, $vcf_pos) = split("\t", $input_line);

    my (@unaffected, $pvalues_chr, $pvalues_pos, $affected);
    while(my $pvalues_line = $pvalues->getline) {
        #($pvalues_chr,$pvalues_pos, $unaffected[0], $unaffected[1], $affected) = split "\t", $pvalues_line; ###generic method for any kind of family later
        my @fields = split"\t", $pvalues_line;
        my $pvalues_chr = $fields[0];
        my $pvalues_pos = $fields[1];
        splice(@fields,0,2);
        my $pass = 1;
        for my $idx (@{$unaffecteds}) {
            my $unaff_pval = $fields[$idx];
# debug            $self->status_message("Examining individual at index $idx, p-value $unaff_pval, line was $pvalues_line");
            if($unaff_pval < $pvalue_cutoff) {
                $pass=0;
            }
        }

        while(!($pvalues_chr eq $vcf_chr and $pvalues_pos eq $vcf_pos)) {
            $input_line = $input_file->getline;
            unless ($input_line) {
                die $self->error_message("Failed to find a vcf line to match the chromosome $pvalues_chr and position $pvalues_pos from pvalues line $pvalues_line");
            }
            ($vcf_chr, $vcf_pos) = split("\t", $input_line);
        }

        unless ($pass) {
            # FIXME replace this with sane methods (like calling $self->fail_vcf_line)
            my @fields = split "\t", $input_line;
            $fields[6] = $filter_name;
            $input_line = join "\t", @fields;
        }
        $output_file->print($input_line);
    }

    return 1;
}

sub prepare_readcount_files {
    my $self = shift;
    my $ref_fasta = shift;
    my $sites_file = shift;
    my $alignment_results_ref = shift;
    my @readcount_files;
    my $qual = $self->min_read_qual;
    for my $alignment_result(@$alignment_results_ref) {
        my $sample_name = $self->find_sample_name_for_alignment_result($alignment_result);

        my $readcount_out = Genome::Sys->create_temp_file_path($sample_name . ".readcount.output");
        my $bam = $alignment_result->merged_alignment_bam_path;
        push @readcount_files, $readcount_out;
        my $readcount_cmd = "bam-readcount -q $qual -f $ref_fasta -l $sites_file $bam > $readcount_out";
        unless(-s $readcount_out) {
            print STDERR "running $readcount_cmd";
            print `$readcount_cmd`;
        }
    }
    return \@readcount_files;
}

sub prepare_r_input {
    my $self = shift;
    my $vcf_fh = shift;
    my $readcount_files = shift;
    my ($r_input_fh,$r_input_path) = Genome::Sys->create_temp_file();
    while (my $line = $vcf_fh->getline) {
        next if ($line =~ m/^#/);
        chomp($line);
        my ($chr, $pos, $id, $ref, $alt, $qual, $filter, $info, $format, @samples) = split "\t", $line;
        my @alts = split ",", $alt;
        my @possible_alleles = ($ref, @alts);
        my $novel = 0;

        for (my $i = 0; $i < @samples; $i++) {
            my ($gt, $rest) = split ":", $samples[$i];
            my ($all1, $all2) = split "[|/]", $gt;
            unless(grep {/$all1/} @possible_alleles) {
                $novel = $all1;
            }
            unless(grep {/$all2/} @possible_alleles) {
                $novel = $all2;
            }
        }

        if($novel) {
            $r_input_fh->print("$chr\t$pos");
            for (my $i = 0; $i < @samples; $i++) {
                my $readcount_file = $readcount_files->[$i];
                chomp(my $readcount_line = `grep "^$chr\t$pos" $readcount_file`);
                my ($chr, $pos, $rc_ref, $depth, @fields) = split "\t", $readcount_line;
                my $prob;
                my ($gt, $rest) = split ":", $samples[$i];
                my @ref_bases = split "[|/]", $gt;
                if(grep /$novel/, @ref_bases) {
                    $prob = .5;
                }
                else {
                    $prob = .01;
                }
                my $ref_depth=0;
                my $var_depth=0;
                if($readcount_line) {
                    for my $fields (@fields) {
                        my ($base, $depth, @rest)  = split ":", $fields;
                        next if($base =~m/\+/);
                        if($base eq $novel) {
                            $var_depth+=$depth;
                        }
                        else {
                            $ref_depth+=$depth;
                        }
                    }
                }
                $r_input_fh->print("\t$var_depth\t$ref_depth\t$prob");
            }
            $r_input_fh->print("\n");
        }
    }
    $r_input_fh->close;
    return $r_input_path;
}

sub r_code {
    my $self = shift;
    my $input_name = shift;
    my $output_name = shift;
    return <<EOS
options(stringsAsFactors=FALSE);
mytable=read.table("$input_name");
num_indices=(ncol(mytable)-2)/3
pvalue_matrix=matrix(nrow=nrow(mytable), ncol=num_indices);
indices = seq(from=3,to=num_indices*3, by=3)
for (i in 1:nrow(mytable)) {
    for (j in indices) {
        pvalue_matrix[i,(j/3)]=binom.test(as.vector(as.matrix(mytable[i,j:(j+1)])), 0, mytable[i,(j+2)], "t", .95)\$p.value;
    }
}
chr_pos_matrix=cbind(mytable\$V1,mytable\$V2, pvalue_matrix);
write(t(chr_pos_matrix), file="$output_name", ncolumns=(num_indices+2), sep="\t");
EOS
}

sub _generate_standard_files {
    return 1;
}

1;
