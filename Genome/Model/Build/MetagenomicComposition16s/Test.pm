
package Genome::Model::Build::MetagenomicComposition16s::Test;

use warnings;
use strict;

use base 'Genome::Utility::TestBase';

use Carp 'confess';
use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Build::MetagenomicComposition16s';
}

sub _model {
    my $self = shift;

    unless ( $self->{_model} ) {
        $self->{_model} = Genome::Model::Test->create_basic_mock_model(
            type_name => 'metagenomic composition 16s sanger'
        ) or die "Can't create metagenomic composition 16s sanger model";
    }
    
    return $self->{_model};
}

sub params_for_test_class {
    return (
        model_id => $_[0]->_model->id,
    );
}

sub required_params_for_class {
    return (qw/ model_id /);
}

sub startup : Tests(startup => no_plan) {
    my $self = shift;

    $self->_ur_no_commit_and_dummy_ids or die;

    return 1;
}

sub tests : Tests() {
    my $self = shift;

    my $build = $self->{_object};

    # dirs
    for my $sub_dir (qw/ classification fasta /) { 
        my $dir .= $sub_dir.'_dir';
        ok(-d $build->$dir, "$sub_dir dir exists")
    }

    # files
    my $file_base_name = $build->file_base_name;
    is($file_base_name, 'H_GV-933124G-S.MOCK', 'build file base name');
    my $fasta_base = $build->data_directory."/fasta/$file_base_name";
    my %file_methods_and_results = (
        processed_fasta_file => $fasta_base.'.processed.fasta',
        processed_qual_file => $fasta_base.'.processed.fasta.qual',
        oriented_fasta_file => $fasta_base.'.oriented.fasta',
        oriented_qual_file => $fasta_base.'.oriented.fasta.qual',
    );
    for my $method ( keys %file_methods_and_results ) {
        is($build->$method, $file_methods_and_results{$method}, $method);
    }
    
    # description
    is(
        $build->description, 
        #qr/metagenomic composition 16s sanger build (-\d) for model (mr. mock -\d)/,
        sprintf( 'metagenomic composition 16s sanger build (%s) for model (%s %s)',
            $build->id, $build->model->name, $build->model->id,
        ),
        'description',
    );

    # link dirs
    my $source_dir = '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16sSanger/build/';
    $self->_link_dirs($source_dir.'/chromat_dir', $build->chromat_dir);
    $self->_link_dirs($source_dir.'/edit_dir', $build->edit_dir);
    $self->_link_dirs($source_dir.'/classification', $build->classification_dir);

    # amplicon - just one for testing
    my $amplicon_iterator = $build->amplicon_iterator;
    my $amplicon = $amplicon_iterator->();
    ok($amplicon, 'got amplicon');
    
    # classification
    my $classification_file = $build->classification_file_for_amplicon($amplicon);
    is(
        $classification_file,
        $build->classification_dir.'/'.$amplicon->name.'.classification.stor',
        'classification file',
    );
    #print $build->data_directory."\n";<STDIN>;
    ok(!$amplicon->classification(undef), 'undef amplicon classification');
    ok($build->load_classification_for_amplicon($amplicon), 'loaded classification');
    ok($amplicon->classification, 'got amplicon classification');
    unlink $classification_file;
    ok($build->save_classification_for_amplicon($amplicon), 'saved classification');
    ok(-s $classification_file, 'classification file exists');
    
    # orient
    ok($build->orient_amplicons_by_classification, 'orient amplicons');

    return 1;
}

sub _link_dirs {
    my ($self, $source_dir, $dest_dir) = @_;

    Genome::Utility::FileSystem->validate_existing_directory($dest_dir)
        or confess;

    my $dh = Genome::Utility::FileSystem->open_directory($source_dir)
        or confess;

    $dh->read; $dh->read; # . and .. dirs
    while ( my $file = $dh->read ) {
        my $target = "$source_dir/$file";
        my $link =  $dest_dir.'/'.$file;
        unless ( symlink($target, $link) ) {
            confess "Can't symlink ($target) to ($link): $!.";
        }
    }

    return 1;
}


###########################################################################

package Genome::Model::Build::MetagenomicComposition16s::Amplicon::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

require Bio::Seq::Quality;
use Data::Dumper 'Dumper';
use Test::More;

sub amplicon {
    return $_[0]->{_object};
}

sub test_class {
    'Genome::Model::Build::MetagenomicComposition16s::Amplicon';
}

sub params_for_test_class {
    my $self = shift;
    my $bioseq = $self->_bioseq;
    return (
        name => $bioseq->id,
        #directory => '/gsc/var/cache/testsuite/data/Genome-Model-AmpliconAssembly/edit_dir',
        reads => [qw/ 
            HMPB-aad13e12.b1 HMPB-aad13e12.b2 HMPB-aad13e12.b3 
            HMPB-aad13e12.b4 HMPB-aad13e12.g1 HMPB-aad13e12.g2 
        /],
        bioseq => $bioseq,
        classification => $self->_classification,
    );
}

sub _bioseq {
    my $self = shift;

    unless ( $self->{_bioseq} ) {
        $self->{_bioseq} = Bio::Seq->new(
            '-id' => 'HMPB-aad13e12',
            '-seq' => 'ATTACCGCGGCTGCTGGCACGTAGCTAGCCGTGGCTTTCTATTCCGGTACCGTCAAATCCTCGCACTATTCGCACAAGAACCATTCGTCCCGATTAACAGAGCTTTACAACCCGAAGGCCGTCATCACTCACGCGGCGTTGCTCCGTCAGACTTTCGTCCATTGCGGAAGATTCCCCACTGCTGCCTCCCGTAGGAGTCTGGGCCGTGTCTCAGTCCCAATGTGGCCGTTCATCCTCTCAGACCGGCTACTGATCATCGCCTTGGTGGGCCGTTACCCCTCCAACTAGCTAATCAGACGCAATCCCCTCCTTCAGTGATAGCTTATAAATAGAGGCCACCTTTCATCCAGTCTCGATGCCGAGATTGGGATCGTATGCGGTATTAGCAGTCGTTTCCAACTGTTGTCCCCCTCTGAAGGGCAGGTTGATTACGCGTTACTCACCCGTTCGCCACTAAGATTGAAAGAAGCAAGCTTCCATCGCTCTTCGTTCGACTTGCATGTGTTAAGCACGCCG',
        ),
    }

    return $self->{_bioseq};
}

sub _classification {
      my $self = shift;

    unless ( $self->{_classification} ) {
        $self->{_classification} = Storable::retrieve(
            '/gsc/var/cache/testsuite/data/Genome-Model/MetagenomicComposition16sSanger/build/classification/HMPB-aad13e12.classification.stor'
        ) or die;
    }

    return $self->{_classification};
}

sub test01_accessors : Tests {
    my $self = shift;

    my $bioseq = $self->_bioseq;
    my $amplicon = $self->amplicon;
    is($amplicon->name, $bioseq->id, 'name');
    ok($amplicon->oriented_bioseq, 'oriented bioseq');

    return 1;
}

###########################################################################

package Genome::Model::Build::MetagenomicComposition16s::Sanger::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Genome::Model::Test;
use Test::More;

sub test_class {
    return 'Genome::Model::Build::MetagenomicComposition16s::Sanger';
}

sub params_for_test_class {
    return (
        model_id => $_[0]->_model->id,
        data_directory => $_[0]->_model->data_directory.'/build',
    );
}

sub required_params_for_class {
    return;
}

sub _model { 
    my $self = shift;

    unless ( $self->{_model} ) {
        $self->{_model} = Genome::Model::Test->create_basic_mock_model(
            type_name => 'metagenomic composition 16s sanger',
            use_mock_dir => 1,
        ) or die "Can't create metagenomic composition 16s sanger model";
    }

    return $self->{_model};
}

sub _build {
    return $_[0]->{_object};
}

sub startup : Tests(startup => no_plan) {
    my $self = shift;

    $self->_ur_no_commit_and_dummy_ids
        or return;

    return 1;
}

sub test02_amplicons_gsc : Tests() {
    my $self = shift;
    
    my $build = $self->_build;
    
    my $amplicons = [];
    my $amplicon_iterator = $build->amplicon_iterator;
    while ( my $amplicon = $amplicon_iterator->() ) {
        push @$amplicons, $amplicon;
    }

    is_deeply(
        [ map { $_->name } @$amplicons ],
        [qw/ HMPB-aad13a05 HMPB-aad13e12 HMPB-aad15e03 HMPB-aad16a01 HMPB-aad16c10 /],
        'Got 5 amplicons',
    );

    # reads for amplicon
    my $amplicon_reads = $amplicons->[0]->reads;
    my @reads = $build->get_all_amplicons_reads_for_read_name(
        $amplicon_reads->[0],
    );
    is_deeply(\@reads, $amplicons->[0]->reads, 'Got all amplicons reads for read name');
    
    # Setup for contamination and latest iteration
    my %mock_reads = $self->_create_mock_gsc_sequence_reads or die;
    no warnings 'redefine';
    #local *Genome::Model::Build::MetagenomicComposition16s::Sanger::_get_gsc_sequence_read = sub{ 
    local *GSC::Sequence::Read::get = sub{ 
        die "No mock read for ".$_[2] unless exists $mock_reads{$_[2]};
        return $mock_reads{$_[2]};
    };
    
    # Contamination - should get 4 amplicons
    $build->processing_profile->exclude_contaminated_amplicons(1);
    $amplicon_iterator = $build->amplicon_iterator;
    my @uncontaminated_amplicons;
    while ( my $amplicon = $amplicon_iterator->() ) {
        push @uncontaminated_amplicons, $amplicon;
    }
    is_deeply(
        [ map { $_->name } @uncontaminated_amplicons ],
        [qw/ HMPB-aad13a05 HMPB-aad13e12 HMPB-aad16a01 HMPB-aad16c10 /],
        'Got 4 uncontaminated amplicons using all read iterations',
    );

    # Latest iteration of reads - 5 amplicons because the contaminated read is older
    $build->processing_profile->only_use_latest_iteration_of_reads(1);
    my @only_latest_reads_amplicons;
    $amplicon_iterator = $build->amplicon_iterator;
    while ( my $amplicon = $amplicon_iterator->() ) {
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
    
    return 1;
}

sub _create_mock_gsc_sequence_reads {
    my $self = shift;

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

###########################################################################

package Genome::Model::Build::MetagenomicComposition16s::454::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Genome::Model::Test;
use Test::More;

sub test_class {
    return 'Genome::Model::Build::MetagenomicComposition16s::454';
}

sub params_for_test_class {
    return (
        model_id => $_[0]->_model->id,
        data_directory => $_[0]->_model->data_directory.'/build',
    );
}

sub required_params_for_class {
    return;
}

sub _model { 
    my $self = shift;

    unless ( $self->{_model} ) {
        $self->{_model} = Genome::Model::Test->create_basic_mock_model(
            type_name => 'metagenomic composition 16s 454',
            use_mock_dir => 1,
        ) or die "Can't create metagenomic composition 16s 454 model";
    }

    return $self->{_model};
}

sub _build {
    return $_[0]->{_object};
}

sub startup : Tests(startup => no_plan) {
    my $self = shift;

    $self->_ur_no_commit_and_dummy_ids
        or return;

    return 1;
}

sub test02_amplicons_gsc : Tests() {
    my $self = shift;
    
    # amplicons
    my $build = $self->_build;
    #print $build->directory."\n";<STDIN>;
    my $amplicons = $build->amplicon_iterator;
    ok($amplicons, 'amplicons');

    my @amplicons;
    while ( my $amplicon = $amplicons->() ) {
        isa_ok($amplicon, 'Genome::Model::Build::MetagenomicComposition16s::Amplicon');
        push @amplicons, $amplicon;
    }
    is(scalar(@amplicons), 5, 'got 5 amplicons');

    is_deeply(
        [ map { $_->name } @amplicons ],
        [qw/ GAERVYW02HRO7O GAERVYW02JNAIR GAERVYW02JDP3V GAERVYW02IPYOY GAERVYW02FOAHL /],
        'Amplicon names match',
    );

    return 1;
}

###########################################################################

1;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2009 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

