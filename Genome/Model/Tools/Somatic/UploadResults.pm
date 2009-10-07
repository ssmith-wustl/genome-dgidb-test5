package Genome::Model::Tools::Somatic::UploadResults;

use strict;
use warnings;
use Genome;
use Genome::Info::IUB;

class Genome::Model::Tools::Somatic::UploadResults {
    is => 'Command',
    has => [
    variant_file => {
        is  => 'String',
        doc => 'The file of somatic pipeline results to be uploaded. This will usually be a high confidence tier 1 or 2 snp file, or a tier 1 indel file from the somatic pipeline.',
    },
    annotation_file => {
        is  => 'String',
        doc => 'The file containing the annotation of all of the variants from the corresponding variant file. This will usually be the annotation output for snps or indels from the somatic pipeline.',
    },
    output_file => {
        is  => 'String',
        doc => 'The output file containing all of the annotation lines from the annotation_file for each of the variants from the variant_file',
    },
    build_id => {
        is => 'Number',
        doc => 'The build id that should be linked to the variant. This is manual for now and required.',
    },
    ],
};

sub help_brief {
    "Adds results from the somatic pipeline to the database tables for tracking all known tier 1 and 2 variants.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
    genome-model tools somatic upload-results --variant-file high_confidence_file.out --annotation-file annotation_file.out --output-file upload.out
EOS
}

sub help_detail {                           
    return <<EOS 
Adds results from the somatic pipeline to the database tables for tracking all known tier 1 and 2 variants. 
EOS
}

sub execute {
    my $self = shift;

    my $variant_fh = IO::File->new($self->variant_file);
    unless ($variant_fh) {
        $self->error_message("Could not open variant file: " . $self->variant_file . " for reading. $!");
        die;
    }

    my $annotation_fh = IO::File->new($self->annotation_file);
    unless ($annotation_fh) {
        $self->error_message("Could not open annotation file: " . $self->annotation_file . " for reading. $!");
        die;
    }

    my $ofh = IO::File->new($self->output_file, "w");
    unless($ofh) {
        $self->error_message("Unable to open " . $self->output_file . " for writing. $!");
        die;
    }

    # Fill the variant hash to later lookup and grab ALL annotation lines for each variant... help... i've turned into dlarson (just kidding dave, I <3 you)
    # FIXME this is pretty hacky going through both files and using the hash and everything... it would be nice to clean this up but for now lets get it working
    my %annotation;
    while(my $line = $annotation_fh->getline) {
        my ($chr, $start, $stop, $reference, $variant, $variation_type, $gene, $transcript, $species, $transcript_source, $transcript_version, $strand, $transcript_status, $type, $aa_string) = split "\t", $line;
        push ( @{$annotation{$chr}{$start}{$stop}{$reference}{$variant}}, $line);
    }
    
    # Go through each line in the variant file and get each annotation line that matches from the annotation file
    # For each line, print it to the output file and upload it to the database
    while (my $line = $variant_fh->getline) {
        my ($chr, $start, $stop, $reference, $variant) = split "\t", $line;

        # Get each possible variant from IUB code
        my @variant_alleles = Genome::Info::IUB->variant_alleles_for_iub($reference, $variant);

        $DB::single=1;
        for my $variant_allele (@variant_alleles) {
            # There should be annotation for each variant line, or something went wrong in the pipeline
            unless (defined $annotation{$chr}{$start}{$stop}{$reference}{$variant_allele}) {
                $self->error_message("Could not find annotation for variant: $chr $start $stop $reference $variant");
                die;
            }

            # This should hold the entire annotation line from the transcript annotation file
            for my $annotation (@{$annotation{$chr}{$start}{$stop}{$reference}{$variant_allele}}) {
                $ofh->print("$annotation");
                my ($chr, $start, $stop, $reference, $variant, $variation_type, $gene, $transcript, $species, $transcript_source, $transcript_version, $strand, $transcript_status, $trv_type, $c_position, $amino_acid_change, $ucsc_cons, $domain) = split("\t", $annotation);
                my $new_variant = Genome::Model::Variant->create(
                    chromosome         => $chr,
                    start_pos          => $start,
                    stop_pos           => $stop,
                    reference_allele   => $reference,
                    variant_allele     => $variant,
                    gene_name          => $gene,
                    transcript_name    => $transcript,
                    transcript_source  => $transcript_source,
                    transcript_version => $transcript_version,
                    strand             => $strand,
                    transcript_status  => $transcript_status,
                    trv_type           => $trv_type,
                    c_position         => $c_position,
                    amino_acid_change  => $amino_acid_change,
                    ucsc_cons          => $ucsc_cons,
                    domain             => $domain,
                    validation_status  => 'P', #FIXME chris says this column should be removed since we arent storing model id in this table... we will just have a final answer in the bridge table
                );

                my $new_build_variant = Genome::Model::BuildVariant->create(
                    variant => $new_variant,
                    build_id => $self->build_id,
                );

            }
        }
    }

    return 1;

}

1;
