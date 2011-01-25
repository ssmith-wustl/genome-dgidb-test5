#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::MetagenomicComposition16s::Test;
use Test::More;

# use
use_ok('Genome::Model::Build::MetagenomicComposition16s::Sanger') or die;

# mock model
my $model = Genome::Model::MetagenomicComposition16s::Test->get_mock_model(
    sequencing_platform => 'sanger',
) or die "Can't create metagenomic composition 16s sanger model";
ok($model, 'MC16s sanger model');

# create w/o subclass
my $build = Genome::Model::Build::MetagenomicComposition16s->create(
    model_id => $model->id,
    data_directory => $model->data_directory.'/build',
);
isa_ok($build, 'Genome::Model::Build::MetagenomicComposition16s::Sanger');

# description
is(
    $build->description, 
    #qr/metagenomic composition 16s sanger build (-\d) for model (mr. mock -\d)/,
    sprintf( 'metagenomic composition 16s sanger build (%s) for model (%s %s)',
        $build->id, $build->model->name, $build->model->id,
    ),
    'description',
);

# metrics (starting)
is($build->amplicons_attempted(5), 5, 'amplicons attempted');
is($build->amplicons_processed(4), 4, 'amplicons processed');
is(
    $build->amplicons_processed_success( 
        $build->amplicons_processed / $build->amplicons_attempted
    ), .8, 'amplicons processed success'
);

# calculated kb
is($build->calculate_estimated_kb_usage, 30000, 'Estimated kb usage');

# dirs
my $existing_build_dir = '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16sSanger/build';
ok(-d $existing_build_dir, 'existing build dir exists');
for my $subdir (qw/ chromat_dir edit_dir phd_dir /) {
    my $dir = $build->$subdir;
    is($dir, $build->data_directory.'/'.$subdir, "$subdir is correct");
    ok(-d $dir, "$subdir was created");
    # link the contents of these
    ok(_link_dir_contents($existing_build_dir.'/'.$subdir, $dir), "linked $subdir") or die;
}

my $classification_dir = $build->classification_dir;
is($classification_dir, $build->data_directory.'/classification', 'classification_dir');
ok(-d $classification_dir, 'classification_dir exists');

my $amplicon_classifications_dir = $build->amplicon_classifications_dir;
is($amplicon_classifications_dir, $build->data_directory.'/sys', 'amplicon_classifications_dir');
ok(-d $amplicon_classifications_dir, 'amplicon_classifications_dir exists');

my $fasta_dir = $build->fasta_dir;
is($fasta_dir, $build->data_directory.'/fasta', 'fasta_dir');
ok(-d $fasta_dir, 'fasta_dir exists');
ok(_link_dir_contents($existing_build_dir.'/fasta', $fasta_dir), "linked fasta_dir") or die;


# file base
my $file_base_name = $build->file_base_name;
is($file_base_name, 'H_GV-933124G-S.MOCK', 'build file base name');

# fastas
my $fasta_base = $fasta_dir."/$file_base_name";
my %file_methods_and_results = (
    processed_fasta_file => $fasta_base.'.processed.fasta',
    processed_qual_file => $fasta_base.'.processed.fasta.qual',
    oriented_fasta_file => $fasta_base.'.oriented.fasta',
    oriented_qual_file => $fasta_base.'.oriented.fasta.qual',
);
for my $method ( keys %file_methods_and_results ) {
    is($build->$method, $file_methods_and_results{$method}, $method);
}

# amplicon sets
my @amplicon_sets = $build->amplicon_sets;
is(scalar(@amplicon_sets), 1, 'Got one amplicon set');
my $amplicon_set = $amplicon_sets[0];
my @amplicons;
while ( my $amplicon = $amplicon_set->next_amplicon ) {
    push @amplicons, $amplicon;
}
is(scalar(@amplicons), 5, 'Got 5 amplicons');

is_deeply(
    [ map { $_->name } @amplicons ],
    [qw/ HMPB-aad13a05 HMPB-aad13e12 HMPB-aad15e03 HMPB-aad16a01 HMPB-aad16c10 /],
    'Got 5 amplicons',
);

#< CLASSIFY >#
my $classification_file = $build->classification_file_for_set_name( $amplicon_set->name );
is(
    $classification_file, 
    $classification_dir.'/'.$file_base_name.'.'.$build->classifier,
    'classification file name for set name \''.$amplicon_set->name.'\' is correct');
is(
    $classification_file, 
    $amplicon_set->classification_file,
    'classification file name from build and amplicon set match',
);
ok($build->classify_amplicons, 'classify amplicons');
ok(-s $classification_file, 'created classification file');
for my $amplicon ( @amplicons ) {
    my $classification_file = $build->classification_file_for_amplicon_name($amplicon->name);
    is(
        $classification_file,
        $amplicon_classifications_dir.'/'.$amplicon->name.'.classification.stor',
        "classification file for amplicon name: ".$amplicon->name,
    );
    next unless -e $classification_file; # one does not classify cuz it didn't assemble
    isa_ok($amplicon->classification, 'Genome::Utility::MetagenomicClassifier::SequenceClassification');
}
is($build->amplicons_classified, 4, 'amplicons classified');
is($build->amplicons_classified_success, '1.00', 'amplicons classified success');
is($build->amplicons_classification_error, 0, 'amplicons classified error');

#< ORIENT ># rm files, orient, check
ok(unlink($build->oriented_fasta_file), 'unlinked oriented fasta file');
ok(unlink($build->oriented_qual_file), 'unlinked oriented qual file');
ok($build->orient_amplicons, 'orient amplicons');
ok(-s $build->oriented_fasta_file, 'created oriented fasta file');
ok(-s $build->oriented_qual_file, 'created oriented qual file');

# Setup for contamination and latest iteration
my %mock_reads = _create_mock_gsc_sequence_reads() or die;
no warnings 'redefine';
no warnings 'once';
local *GSC::Sequence::Read::get = sub{ 
    die "No mock read for ".$_[2] unless exists $mock_reads{$_[2]};
    return $mock_reads{$_[2]};
};
use warnings;

# contamination - should get 4 amplicons
$build->processing_profile->exclude_contaminated_amplicons(1);
@amplicon_sets = $build->amplicon_sets;
$amplicon_set = $amplicon_sets[0];
my @uncontaminated_amplicons;
while ( my $amplicon = $amplicon_set->next_amplicon ) {
    push @uncontaminated_amplicons, $amplicon;
}
is_deeply(
    [ map { $_->name } @uncontaminated_amplicons ],
    [qw/ HMPB-aad13a05 HMPB-aad13e12 HMPB-aad16a01 HMPB-aad16c10 /],
    'Got 4 uncontaminated amplicons using all read iterations',
);

# latest iteration of reads - 5 amplicons because the contaminated read is older
$build->processing_profile->only_use_latest_iteration_of_reads(1);
my @only_latest_reads_amplicons;
@amplicon_sets = $build->amplicon_sets;
$amplicon_set = $amplicon_sets[0];
while ( my $amplicon = $amplicon_set->next_amplicon ) {
    push @only_latest_reads_amplicons, $amplicon;
}
is_deeply(
    [ map { $_->name } @only_latest_reads_amplicons ],
    [qw/ HMPB-aad13a05 HMPB-aad13e12 HMPB-aad15e03 HMPB-aad16a01 HMPB-aad16c10 /],
    'Got 5 uncontaminated amplicons using only latest read iterations',
);
is_deeply(
    $only_latest_reads_amplicons[0]->reads,
    [qw/ 
    HMPB-aad13a05.b3
    HMPB-aad13a05.b4
    HMPB-aad13a05.g1
    /],
    'Got latest iterations for reads'
);

done_testing();
exit;

#####################################################################################

sub _link_dir_contents {
    my ($source_dir, $dest_dir) = @_;

    Genome::Sys->validate_existing_directory($dest_dir)
        or die;

    my $dh = Genome::Sys->open_directory($source_dir)
        or die;

    $dh->read; $dh->read; # . and .. dirs
    while ( my $file = $dh->read ) {
        my $target = "$source_dir/$file";
        my $link =  $dest_dir.'/'.$file;
        unless ( symlink($target, $link) ) {
            die "Can't symlink ($target) to ($link): $!.";
        }
    }

    return 1;
}

sub _create_mock_gsc_sequence_reads {
    my %reads;
    my %read_params = (
        'HMPB-aad13a05.b1' => {
            'run_date' => '16-MAY-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13a05.b2' => {
            'run_date' => '17-MAY-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad13a05.b3' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13a05.b4' => {
            'run_date' => '02-OCT-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad13a05.g1' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13a05.g2' => {
            'run_date' => '20-MAY-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13e12.b1' => {
            'run_date' => '16-MAY-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13e12.b2' => {
            'run_date' => '17-MAY-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad13e12.b3' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13e12.b4' => {
            'run_date' => '02-OCT-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad13e12.g1' => {
            'run_date' => '20-MAY-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad13e12.g2' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad15e03.b1' => {
            'run_date' => '16-MAY-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad15e03.b2' => {
            'run_date' => '17-MAY-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad15e03.b3' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad15e03.b4' => {
            'run_date' => '02-OCT-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad15e03.g1' => {
            'run_date' => '20-MAY-2008',
            'primer_code' => '-28RPpOT',
            # CONTAMINATED READ #
            'is_contaminated' => 1,
        },
        'HMPB-aad15e03.g2' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16a01.b1' => {
            'run_date' => '16-MAY-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16a01.b2' => {
            'run_date' => '17-MAY-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad16a01.b3' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16a01.b4' => {
            'run_date' => '02-OCT-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad16a01.g1' => {
            'run_date' => '20-MAY-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16a01.g2' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16c10.b1' => {
            'run_date' => '16-MAY-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16c10.b2' => {
            'run_date' => '17-MAY-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad16c10.b3' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-21UPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16c10.b4' => {
            'run_date' => '02-OCT-2008',
            'primer_code' => '907R',
            'is_contaminated' => 0,
        },
        'HMPB-aad16c10.g1' => {
            'run_date' => '20-MAY-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
        'HMPB-aad16c10.g2' => {
            'run_date' => '01-OCT-2008',
            'primer_code' => '-28RPpOT',
            'is_contaminated' => 0,
        },
    );
    for my $read_name ( keys %read_params ) {
        $reads{$read_name} = Test::MockObject->new();
        $reads{$read_name}->set_always('trace_name', $read_name);
        my $screen_reads_stat_hmp = Test::MockObject->new();
        $screen_reads_stat_hmp->set_always(
            'is_contaminated',
            $read_params{$read_name}->{is_contaminated}
        );
        $reads{$read_name}->set_always('get_screen_read_stat_hmp', $screen_reads_stat_hmp);
        for my $attr ( keys %{$read_params{$read_name}} ) {
            $reads{$read_name}->set_always($attr, $read_params{$read_name}->{$attr});
        }
    }

    return %reads;
}

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

