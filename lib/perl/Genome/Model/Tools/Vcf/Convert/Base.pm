package Genome::Model::Tools::Vcf::Convert::Base;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Vcf::Convert::Base {
    is => 'Command',
    is_abstract => 1,
    has => [
        output_file => {
            is => 'Text',
            doc => "List of mutations, converted to VCF",
        },
        input_file => {
            is => 'Text',
            doc => "The file to be converted to VCF" ,
        },
        aligned_reads_sample => {
            is => 'Text',
            doc => "The label to be used for the aligned_reads sample in the VCF header",
        },
        control_aligned_reads_sample => {
            is => 'Text',
            doc => "The label to be used for the aligned_reads sample in the VCF header",
            is_optional => 1,
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            doc => 'The reference sequence build used to detect variants',
            id_by => 'reference_sequence_build_id',
        },
        reference_sequence_input => {
            is_constant => 1,
            calculate_from => ['reference_sequence_build'],
            calculate => q|
            my $cache_base_dir = $reference_sequence_build->local_cache_basedir;
            if ( -d $cache_base_dir ) { # WE ARE ON A MACHINE THAT SUPPORTS CACHING
            return $reference_sequence_build->cached_full_consensus_path('fa');
            }
            else { # USE NETWORK REFERENCE
            return $reference_sequence_build->full_consensus_path('fa');
            }
            |,
            doc => 'Location of the reference sequence file',
        },
        sequencing_center => {
            is => 'Text',
            doc => "Center that did the sequencing. Used to figure out the 'reference' section of the header." ,
            default => "WUSTL",
            valid_values => ["WUSTL", "BROAD"],
        },
        vcf_version => {
            is => 'Text',
            doc => "Version of the VCF being printed" ,
            default => "4.0",
            valid_values => ["4.0"],
        },
    ],
    has_transient_optional => [
        _input_fh => {
            is => 'IO::File',
            doc => 'Filehandle for the source variant file',
        },
        _output_fh => {
            is => 'IO::File',
            doc => 'Filehandle for the output VCF',
        },
    ],

    doc => 'Base class for tools that convert lists of mutations to VCF',
};

sub execute {
    my $self = shift;

    unless($self->initialize_filehandles) {
        return;
    }

    $self->print_header;

    $self->convert_file;

    $self->close_filehandles;

    return 1;
}

sub initialize_filehandles {
    my $self = shift;

    if($self->_input_fh || $self->_output_fh) {
        return 1; #Already initialized
    }

    my $input = $self->input_file;
    my $output = $self->output_file;

    eval {
        my $input_fh = Genome::Sys->open_file_for_reading($input);
        my $output_fh = Genome::Sys->open_file_for_writing($output);

        $self->_input_fh($input_fh);
        $self->_output_fh($output_fh);
    };

    if($@) {
        $self->error_message('Failed to open file. ' . $@);
        $self->close_filehandles;
        return;
    }

    return 1;
}

sub close_filehandles {
    my $self = shift;

    my $input_fh = $self->_input_fh;
    close($input_fh) if $input_fh;

    my $output_fh = $self->_output_fh;
    close($output_fh) if $output_fh;

    return 1;
}

# Get the base at this position in the reference. Used when an anchor (previous base) is needed for the reference column
sub get_base_at_position {
    my $self = shift;
    my ($chr,$pos) = @_;

    my $reference = $self->reference_sequence_input;
    Genome::Sys->validate_file_for_reading($reference);
    my $sam_default = Genome::Model::Tools::Sam->path_for_samtools_version;
    my $faidx_cmd = "$sam_default faidx $reference $chr:$pos-$pos";

    my $sequence = `$faidx_cmd | grep -v \">\"`;
    unless ($sequence) {
        die $self->error_message("Failed to get a return from running the faidx command: $faidx_cmd");
    }
    chomp $sequence;
    return $sequence;
}

# Print the header to the output file... currently assumes "standard" columns of GT,GQ,DP,BQ,MQ,AD,FA,VAQ in the FORMAT field and VT in the INFO field.
# TODO this also assumes a somatic file (NORMAL and PRIMARY headers) ...
sub print_header{
    my $self = shift;

    my $file_date = localtime();

    my $public_reference;
    #
    # Calculate the location of the public reference sequence
    my $seq_center = $self->sequencing_center;
    my $reference_sequence_version = $self->reference_sequence_build->version;

    if ($reference_sequence_version == 37) {
        $public_reference = "ftp://ftp.ncbi.nih.gov/genbank/genomes/Eukaryotes/vertebrates_mammals/Homo_sapiens/GRCh37/special_requests/GRCh37-lite.fa.gz";
    } elsif ($reference_sequence_version == 36) {
        if ($seq_center eq "WUSTL"){
            $public_reference = "ftp://ftp.ncbi.nlm.nih.gov/genomes/H_sapiens/ARCHIVE/BUILD.36.3/special_requests/assembly_variants/NCBI36_BCCAGSC_variant.fa.gz";
        } elsif ($seq_center eq "BROAD"){
            $public_reference="ftp://ftp.ncbi.nlm.nih.gov/genomes/H_sapiens/ARCHIVE/BUILD.36.3/special_requests/assembly_variants/NCBI36-HG18_Broad_variant.fa.gz";
        } else {
            die $self->error_message("Unknown sequencing center: $seq_center");
        }
    } else {
        die $self->error_message("Unknown reference sequence version ($reference_sequence_version) from reference sequence build " . $self->reference_sequnce_build_id);
    }

    my $output_fh = $self->_output_fh;

    my $sample = $self->aligned_reads_sample;

    $output_fh->print("##fileformat=VCFv" . $self->vcf_version . "\n");
    $output_fh->print("##fileDate=" . $file_date . "\n");
    $output_fh->print("##reference=$public_reference" . "\n");
    $output_fh->print("##phasing=none" . "\n");
    $output_fh->print("##SAMPLE=" . $sample . "\n");

    #format info
    $output_fh->print("##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">" . "\n");
    $output_fh->print("##FORMAT=<ID=GQ,Number=1,Type=Integer,Description=\"Genotype Quality\">" . "\n");
    $output_fh->print("##FORMAT=<ID=DP,Number=1,Type=Integer,Description=\"Total Read Depth\">" . "\n");
    $output_fh->print("##FORMAT=<ID=BQ,Number=1,Type=Integer,Description=\"Average Base Quality corresponding to alleles 0/1/2/3... after software and quality filtering\">" . "\n");
    $output_fh->print("##FORMAT=<ID=MQ,Number=1,Type=Integer,Description=\"Average Mapping Quality corresponding to alleles 0/1/2/3... after software and quality filtering\">" . "\n");
    $output_fh->print("##FORMAT=<ID=AD,Number=1,Type=Integer,Description=\"Allele Depth corresponding to alleles 0/1/2/3... after software and quality filtering\">" . "\n");
    $output_fh->print("##FORMAT=<ID=FA,Number=1,Type=Float,Description=\"Fraction of reads supporting ALT\">" . "\n");
    $output_fh->print("##FORMAT=<ID=VAQ,Number=1,Type=Integer,Description=\"Variant Quality\">" . "\n"); # FIXME this is sometimes a Float and sometimes an Integer

    #INFO
    $output_fh->print("##INFO=<ID=VT,Number=1,Type=String,Description=\"Variant type\">" . "\n");

    #column header:
    $output_fh->print( "#" . join("\t", ("CHROM","POS","ID","REF","ALT","QUAL","FILTER","INFO","FORMAT","NORMAL","PRIMARY")) . "\n");

    return 1;
}

sub convert_file {
    my $self = shift;
    my $input_fh = $self->_input_fh;

    while(my $line = $input_fh->getline) {
        chomp $line;
        my $output_line = $self->parse_line($line);
        $self->write_line($output_line);
    }

    return 1;
}

sub write_line {
    my $self = shift;
    my $line = shift;

    my $output_fh = $self->_output_fh;
    print $output_fh "$line\n";

    return 1;
}

# Generates the "GT" field. A 0 indicates matching reference. Any other number indicates matching that variant in the available "alt" alleles.
# I.E. REF: A ALT: C,T ... a A/C call in the GT field would be: 0/1. A C,T call in the GT field would be: 1/2
# alt alleles is an arrayref of  the alleles from the "ALT" column, all calls for this position that don't match the reference.
# genotype alleles is an arrayref of the alleles called at this position for this sample, including those that match the reference
sub generate_gt {
    my ($self, $reference, $alt_alleles, $genotype_alleles) = @_;
    my @gt_string;
    for my $genotype_allele (@$genotype_alleles) {
        my $allele_number;
        if ($genotype_allele eq $reference) {
            $allele_number = 0;
        } else {
            # Find the index of the alt allele that matches this genotype allele, add 1 to offset 0 based index
            for (my $i = 0; $i < scalar @$alt_alleles; $i++) {
                if ($genotype_allele eq @$alt_alleles[$i]) {
                    $allele_number = $i + 1; # Genotype index starts at 1
                }
            }
        }
        unless (defined $allele_number) {
            die $self->error_message("Could not match genotype allele $genotype_allele to any allele from the ALT field");
        }

        push(@gt_string, $allele_number);
    }

    # the GT field is sorted out of convention... you'll see 0/1 but not 1/0
    return join("/", sort(@gt_string));
}

sub parse_line {
    my $self = shift;

    $self->error_message('The parse_line() method should be implemented by subclasses of this module.');
    return;
}

1;
