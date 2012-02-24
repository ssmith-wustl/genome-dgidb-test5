package Genome::Model::MutationalSignificance::Command::CreateMafFile;

use strict;
use warnings;

use Genome;
use Sort::Naturally qw(nsort);

class Genome::Model::MutationalSignificance::Command::CreateMafFile {
    is => ['Command::V2'],
    has_input => [
        somatic_variation_build => {
            is => 'Genome::Model::Build::SomaticVariation',
        },
        output_dir => {
            is => 'Text',
        },
    ],
    has_output => [
        maf_file => {},
    ],
};

sub execute {
    my $self = shift;

    my $rand = rand();

    my $snv_file = $self->output_dir."/".$self->somatic_variation_build->id.".uhc.anno";

    #Deduplicate and sort the snv file (copied from gmt capture manual-review)
    my $snv_anno = $self->somatic_variation_build->data_set_path("effects/snvs.hq.tier1",1,"annotated.top");
    my @snv_lines = `cat $snv_anno`;
    chomp @snv_lines;
    # Store the variants into a hash to help sort variants by loci, and to remove duplicates
    my %review_lines = ();
    my $snv_cnt = 0;
    for my $line ( @snv_lines )
    {
        my ( $chr, $start, $stop, $ref, $var ) = split( /\t/, $line );
        ++$snv_cnt unless( defined $review_lines{snvs}{$chr}{$start}{$stop} );
        $review_lines{snvs}{$chr}{$start}{$stop} = $line; # Save annotation for use with the UHF
    }
    my $snv_anno_file = Genome::Sys->create_temp_file_path;
    my $snv_anno_fh = IO::File->new( $snv_anno_file, ">" ) or die "Cannot open $snv_anno_file. $!";
    for my $chr ( nsort keys %{$review_lines{snvs}} )
    {
        for my $start ( sort {$a <=> $b} keys %{$review_lines{snvs}{$chr}} )
        {
            for my $stop ( sort {$a <=> $b} keys %{$review_lines{snvs}{$chr}{$start}} )
            {
                $snv_anno_fh->print( $review_lines{snvs}{$chr}{$start}{$stop}, "\n" );
            }
        }
    }
    $snv_anno_fh->close;

    #For now, get only the ultra-high-confidence variants
    #TODO: Make a separate list of pindel-only indels
    #TODO: Get files for manual review
    #TODO: Check count of variants to review and set aside if too many
    my $uhc_cmd = Genome::Model::Tools::Somatic::UltraHighConfidence->create(
        normal_bam_file => $self->somatic_variation_build->normal_bam,
        tumor_bam_file => $self->somatic_variation_build->tumor_bam,
        variant_file => $snv_anno_file,
        output_file => $snv_file,
        filtered_file => $self->output_dir."/".$self->somatic_variation_build->id.".not_uhc.anno",
        reference => $self->somatic_variation_build->reference_sequence_build->fasta_file,
    );

    my $uhc_result = $uhc_cmd->execute;

    #TODO: Add reviewed variants back in
    #TODO: Add in the dbSnp variants that appear in COSMIC
    
    my $create_maf_cmd = Genome::Model::Tools::Capture::CreateMafFile->create(
        snv_file => $snv_file,
        snv_annotation_file => $snv_file,
        genome_build => '37', #TODO FIX!!!
        tumor_sample => $self->somatic_variation_build->tumor_build->model->subject->extraction_label, #TODO verify
        normal_sample => $self->somatic_variation_build->normal_build->model->subject->extraction_label, #TODO verify
        output_file => $self->output_dir."/".$self->somatic_variation_build->id.".maf",
    );

    my $create_maf_result = $create_maf_cmd->execute;

    my $cmd = 'perl -an -F\'\t\' -e \'chomp(@F[-1]); @t=`grep "^$F[4]\t$F[5]" '.$snv_file.' | cut -f 8,15,16`; print ($F[0]=~m/^Hugo/ ? (join("\t",@F)."\ttranscript_name\tc_position\tamino_acid_change\n") : (join("\t",@F)."\t".$t[0]));\' '. $self->output_dir."/".$self->somatic_variation_build->id.".maf > ".$self->output_dir."/".$self->somatic_variation_build->id.".maf2";
    Genome::Sys->shellcmd(cmd => $cmd);

    $self->maf_file($self->output_dir."/".$self->somatic_variation_build->id.".maf2");
    my $status = "Created MAF file ".$self->maf_file;
    $self->status_message($status);
    return 1;
}

1;
