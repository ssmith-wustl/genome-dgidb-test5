#review/notes
#This file currently needs to exist because workflow can't pass bare_args.  Long-term solution is to refactor `gmt snp intersect` to not take bare_args.
package Genome::Model::Tools::DetectVariants2::Filter::CeuYri;

use warnings;
use strict;

use Genome;

class Genome::Model::Tools::DetectVariants2::Filter::CeuYri {
    is => 'Genome::Model::Tools::DetectVariants2::Filter',
};

# datasource_file is control_variant_file. Original doc: File of source variation to filter out... this defaults to the current CEU and YRI file (combined)

sub help_brief {
    "runs gmt snp intersect on CEU/YRI files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt filter-variants --output-file filtered.out --variant-file variants.in 
EOS
}

sub help_detail {                           
    return <<EOS 
Filter out CEU and YRI from the variant file... really this is just a wrapper of gmt snp intersect since workflow wont take bare args...
EOS
}

sub _filter_variants {
    my $self = shift;

    my $c_variant_file = $self->control_variant_file || '/gscmnt/834/info/medseq/imported_variants_data/CEU_YRI_all.snps.snpfilter.s';
    
    if (($self->skip_if_output_present) && (-s $self->output_file)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    my $command = Genome::Model::Tools::Snp::Intersect->create(
        f1_only_output => $self->output_file,
        file1 => $self->variant_file,
        file2 => $c_variant_file
    );

    my $return = $command->execute;

    unless ($return == 1) {
        $self->error_message("Intersect command returned $return, expecting 1");
        die;
    }

    return 1;
}


1;
