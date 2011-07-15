package Genome::Model::Tools::Joinx::Union;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Joinx::Union {
    is => 'Genome::Model::Tools::Joinx',
    has_input => [
        input_file_a => {
            is => 'Text',
            doc => 'Sorted bed "A"',
            shell_args_position => 1,
        },
        input_file_b => {
            is => 'Text',
            doc => 'Sorted bed file "B"',
            shell_args_position => 2,
        },
    ],
    has_optional_input => [
        output_file => {
            is => 'Text',
            doc => 'The output file (defaults to stdout)',
        },
        exact_pos => {
            is => 'Boolean',
            default => 0,
            doc => 'require exact position matches (do not count overlaps)',
        },
        exact_allele => {
            is => 'Boolean',
            default => 0,
            doc => 'require exact allele match. implies --exact-pos',
        },
        iub_match => {
            is => 'Boolean',
            default => 0,
            doc => 'when using --exact-allele, this enables expansion and partial matching of IUB codes',
        },
        dbsnp_match => {
            is => 'Boolean',
            default => 0,
            doc => 'Special mode to match alleles to dbsnp and reverse compliment if they do not match the first time',
        },
    ],
};

sub help_brief {
    "Compute union of 2 bed files."
}

sub help_synopsis {
    my $self = shift;
    "gmt joinx union a.bed b.bed [--output-file=n.bed]"
}

sub flags {
    my $self = shift;

    my @flags;
    my @bool_flags = (
        'exact_pos',
        'exact_allele',
        'iub_match',
        'dbsnp_match',
    );
    for my $bf (@bool_flags) {
        if ($self->$bf) {
            my $tmp = "--$bf";
            $tmp =~ tr/_/-/;
            push(@flags, $tmp);
        }
    }
    return @flags;
}

sub execute {
    my $self = shift;
    my $output = "-";
    # Implemented by using itersect with miss-a and miss-b set to the
    # main output stream
    my $output_file = $self->output_file || '-';
    my %params = (
        $self->flags,
        use_version => $self->use_version || '',
        input_file_a => $self->input_file_a,
        input_file_b => $self->input_file_b,
        output_file => $output_file,
        miss_a_file => $output_file,
        miss_b_file => $output_file,
    );

    my $cmd = Genome::Model::Tools::Joinx::Intersect->create(
        \%params
    );
    return $cmd->execute();
}

1;
