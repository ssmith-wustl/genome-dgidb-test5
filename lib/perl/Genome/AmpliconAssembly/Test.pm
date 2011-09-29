###########################################################################

package Genome::AmpliconAssembly::Test;

use strict;
use warnings;

use base 'Test::Class';

use Data::Dumper 'Dumper';
use Test::More;
require File::Temp;
require File::Path;

use Data::Dumper 'Dumper';

sub test_class {
    return 'Genome::AmpliconAssembly';
}

sub amplicon_assembly {
    return $_[0]->{_amplicon_assembly};
}

sub base_test_dir {
    return '/gsc/var/cache/testsuite/data';
}

sub tmp_dir {
    my $self = shift;

    unless ( $self->{_tmp_dir} ) {
        $self->{_tmp_dir} = File::Temp::tempdir(CLEANUP => 1);
    }
    
    return $self->{_tmp_dir};
}

sub test00_use : Test(1) {
    my $self = shift;

    use_ok( $self->test_class )
        or die;

    return 1;
}

sub test01_get : Tests(1) {
    my $self = shift;

    # amplicon assembly for tests below
    $self->{_amplicon_assembly} = $self->test_class->get(
        directory => $self->base_test_dir.'/Genome-Model/AmpliconAssembly/build',
    );
    ok(
        $self->{_amplicon_assembly},
        'get',
    );

    return 1;
}

sub test02_create : Tests(1) {
    my $self = shift;

    my $amplicon_assembly = $self->test_class->create(
        directory => $self->tmp_dir,
    );
    ok(
        $amplicon_assembly,
        'create',
    );

    # Remove properties file and object from UR
    unlink $amplicon_assembly->_properties_file;
    $amplicon_assembly->delete;

    return 1;
}

sub test03_invalid_create : Tests() {
    my $self = shift;

    my %invalid_params = (
        sequencing_center => 'washu',
        sequencing_platform => '373',
    );
    for my $invalid_attr ( keys %invalid_params ) {
        ok(!$self->test_class->create(
                directory => $self->tmp_dir,
                $invalid_attr => $invalid_params{$invalid_attr},
            ),
            "failed as expected - create w/ $invalid_attr\: ".$invalid_params{$invalid_attr},
        );
    }

    ok(
        !$self->test_class->create(
            directory => $self->tmp_dir,
            sequencing_center => 'broad',
            exclude_contaminated_amplicons => 1,
        ), 'Failed as expected - create w/ unsupported attrs for broad',
    );

    return 1;
}

sub test02_amplicons_gsc_sanger : Tests() {
    my $self = shift;
    
    # amplicons
    my $amplicon_assembly = $self->amplicon_assembly;
    #print $amplicon_assembly->directory."\n";<STDIN>;
    my $amplicons = $amplicon_assembly->get_amplicons;
    is_deeply(
        [ map { $_->name } @$amplicons ],
        [qw/ HMPB-aad13a05 HMPB-aad13e12 HMPB-aad15e03 HMPB-aad16a01 HMPB-aad16c10 /],
        'Got 5 amplicons',
    );
    # reads for amplicon
    my @reads = $self->amplicon_assembly->get_all_amplicons_reads_for_read_name(
        ($amplicons->[0]->reads)[0],
    );
    is_deeply(\@reads, $amplicons->[0]->get_reads, 'Got all amplicons reads for read name');
    
    # get amplicons excluding contaminated and using only new recent read
    my %mock_reads = $self->_create_mock_gsc_sequence_reads or die;
    no warnings 'redefine';
    local *Genome::AmpliconAssembly::_get_gsc_sequence_read = sub{ 
        die "No mock read for ".$_[1] unless exists $mock_reads{$_[1]};
        return $mock_reads{$_[1]};
    };
    $amplicon_assembly->exclude_contaminated_amplicons(1);
    my $uncontaminated_amplicons = $amplicon_assembly->get_amplicons;
    is_deeply(
        [ map { $_->name } @$uncontaminated_amplicons ],
        [qw/ HMPB-aad13a05 HMPB-aad13e12 HMPB-aad16a01 HMPB-aad16c10 /],
        'Got 4 uncontaminated amplicons using all read iterations',
    );
    $amplicon_assembly->only_use_latest_iteration_of_reads(1);
    my $only_latest_reads_amplicons = $amplicon_assembly->get_amplicons;
    is_deeply(
        [ map { $_->name } @$only_latest_reads_amplicons ],
        # we get all 5 amplicons here because the read that is contaminated is older
        [qw/ HMPB-aad13a05 HMPB-aad13e12 HMPB-aad15e03 HMPB-aad16a01 HMPB-aad16c10 /],
        'Got 5 uncontaminated amplicons using only latest read iterations',
    );
    is_deeply(
        $only_latest_reads_amplicons->[0]->get_reads,
        [qw/ 
        HMPB-aad13a05.b3
        HMPB-aad13a05.b4
        HMPB-aad13a05.g1
        /],
        'Got latest iterations for reads'
    );
    
    return 1;
}

#:jpeck Maybe move the data in the _create_mock_gsc_sequence_reads into a file?
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

# TODO sub test_02_amplicons_broad_sanger : Tests {

###########################################################################

package Genome::AmpliconAssembly::AmpliconTest;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub amplicon {
    return $_[0]->{_object};
}

sub test_class {
    'Genome::AmpliconAssembly::Amplicon';
}

sub params_for_test_class {
    return (
        name => 'HMPB-aad13e12',
        directory => '/gsc/var/cache/testsuite/data/Genome-Model-AmpliconAssembly/edit_dir',
        reads => [qw/ HMPB-aad13e12.b1 HMPB-aad13e12.b2 HMPB-aad13e12.b3 HMPB-aad13e12.b4 HMPB-aad13e12.g1 HMPB-aad13e12.g2 /],
    );
}

sub invalid_params_for_test_class {
    return (
        directory => 'does_not_exist',
    );
}

sub test01_accessors : Tests {
    my $self = shift;

    my $amplicon = $self->amplicon;

    my %params = $self->params_for_test_class;
    for my $attr ( keys %params ) {
        my $method = 'get_'.$attr;
        is_deeply($amplicon->$method, $params{$attr}, "Got $attr");
    }

    return 1;
}

sub test02_bioseq : Tests {
    my $self = shift;

    my $amplicon = $self->amplicon;
    ok($amplicon->get_bioseq, 'Got bioseq');
    is($amplicon->get_bioseq_source, 'assembly', 'Got source - assembly');
    is($amplicon->was_assembled_successfully, 1, 'Assembled successfully');
    is($amplicon->is_bioseq_oriented, 0, 'Not oriented');
 
    return 1;
}

sub test03_reads : Tests {
    my $self = shift;

    my $amplicon = $self->amplicon;
    my %params = $self->params_for_test_class;
    my $attempted_reads = $params{reads};
    
    my $assembled_reads = $amplicon->get_assembled_reads;
    is_deeply($assembled_reads, $attempted_reads, 'Got source');
    is($amplicon->get_assembled_read_count, scalar(@$assembled_reads), 'Got source');
    my $read_bioseq = $amplicon->get_bioseq_for_raw_read($attempted_reads->[2]);
    is($read_bioseq->id, $attempted_reads->[2], 'Got read bioseq for '.$attempted_reads->[2]);
    my $processed_bioseq = $amplicon->get_bioseq_for_processed_read($attempted_reads->[4]);
    is($processed_bioseq->id, $attempted_reads->[4], 'Got processed bioseq for '.$attempted_reads->[4]);
    
    return 1;
}

sub test04_succesful_assembly_reqs : Tests(3) {
    my $self = shift;

    my $length = $self->test_class->successfully_assembled_length;
    is($length, 1150, 'Successfully assembled length');
    my $cnt = $self->test_class->successfully_assembled_read_count;
    is($cnt, 2, 'Successfully assembled read count');
    is(
        $self->test_class->successfully_assembled_requirements_as_string,
        "length >= $length, reads >= $cnt",
        'Successfully assembled reqs string',
    );

    return 1;
}

sub test03_files {#: Tests {
    my $self = shift;

    #TODO
    
    return 1;
}

###########################################################################


package Genome::Model::Tools::AmpliconAssembly::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
require Genome::Model::Test;
use Test::More;

sub params_for_test_class {
    return (
        directory => $_[0]->amplicon_assembly->directory, # this creates the aa
        $_[0]->_params_for_test_class,
    );
}

sub amplicon_assembly {
    my $self = shift;

    unless ( $self->{_amplicon_assembly} ) {
        $self->{_amplicon_assembly} = Genome::AmpliconAssembly->create(
            directory => $self->tmp_dir,
        );
    }

    return $self->{_amplicon_assembly};
}

sub amplicons {
    return $_[0]->{_object}->get_amplicons;
}

sub _build_dir {
    return $_[0]->base_test_dir.'/Genome-Model-AmpliconAssembly/build-10000';
}

sub _params_for_test_class { return; }
sub should_copy_traces { 1 }
sub should_copy_edit_dir { 1 }
sub _pre_execute { 1 }

sub test01_copy_data : Tests {
    my $self = shift;

    if ( $self->should_copy_traces ) {
        ok( 
            Genome::Model::Test->copy_test_dir(
                $self->_build_dir.'/chromat_dir',
                $self->tmp_dir.'/chromat_dir',
            ),
            "Copy traces"
        ) or die;
    }

    if ( $self->should_copy_edit_dir ) {
        ok(
            Genome::Model::Test->copy_test_dir(
                $self->_build_dir.'/edit_dir',
                $self->tmp_dir.'/edit_dir',
            ),
            "Copy edit_dir"
        ) or die;
    }

    return 1;
}

sub test02_execute : Test(2) {
    my $self = shift;

    ok($self->_pre_execute, 'Pre Execute')
        or die "Failed method _pre_execute\n";

    ok($self->{_object}->execute, "Execute");
    #print $self->{_object}->directory,"\n"; <STDIN>;

    return 1;
}

###########################################################################

package Genome::Model::Tools::AmpliconAssembly::AssembleTest;

use strict;
use warnings;

use base 'Genome::Model::Tools::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Tools::AmpliconAssembly::Assemble';
}

sub invalid_params_for_test_class {
    return (
        assembler_params => 'u-n-p-a-r-s able 00',
    );
}
sub _pre_execute {
    my $self = shift;

    my $amplicons = $self->amplicons;
    for my $amplicon ( @$amplicons ) {
        # remove ace files
        unlink $amplicon->ace_file;
    }

    my $cnt = grep { -s $_->ace_file } @$amplicons;
    die "Could not remove ace files\n" if $cnt;

    return 1;
}

sub test03_verify : Test(1) {
    my $self = shift;

    my $amplicons = $self->amplicons;
    my $ace_cnt = grep { -s $_->ace_file } @$amplicons;
    is($ace_cnt, @$amplicons, 'Verified - Created an acefile for each amplicon');
    
    return 1;
}

###########################################################################

package Genome::Model::Tools::AmpliconAssembly::ClassifyTest;

use strict;
use warnings;

use base 'Genome::Model::Tools::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Tools::AmpliconAssembly::Classify';
}

sub _pre_execute {
    my $self = shift;

    my $amplicons = $self->amplicons;
    for my $amplicon ( @$amplicons ) {
        my $class_file = $amplicon->classification_file;
        unlink $class_file if -e $class_file;
    }

    my $cnt = grep { -s $_->classification_file } @$amplicons;
    die "Could not remove classification files\n" if $cnt;

    return 1;
}

sub test03_verify : Test(1) {
    my $self = shift;

    my $amplicons = $self->amplicons;
    my $cnt = grep { -s $_->classification_file } @$amplicons;
    is($cnt, @$amplicons, 'Verified - Created classification for each amplicon');
    
    return 1;
}

###########################################################################

package Genome::Model::Tools::AmpliconAssembly::ContaminationScreenTest;

use strict;
use warnings;

use base 'Genome::Model::Tools::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Tools::AmpliconAssembly::ContaminationScreen';
}

sub _params_for_test_class {
    return (
        database => '/gsc/var/lib/reference/set/2809160070/blastdb/blast',
        remove_contaminants => 1,
    );
}

sub _pre_execute { 
    # copy in the contaminated reads
    # contaminated read is vjn39g07.g1
    my $self = shift;

    for my $subdir ( (qw/ chromat_dir edit_dir /) ){
        my $source = $self->dir."/$subdir";
        my $dest = $self->tmp_dir."/$subdir";
        my $dh = Genome::Sys->open_directory($source)
            or die;
        while ( my $file = $dh->read ) {
            next if $file =~ m#^\.#;
            File::Copy::copy("$source/$file", $dest)
                or die "Can't copy ($source/$file) to ($dest): $!\n";
        }
    }

    $self->{_pre_execute_amplicons} = [ map { $_->get_name } @{$self->amplicons} ];

    return 1;
}

sub test03_verify : Test(2) {
    my $self = shift;

    # screen file
    my $screen_file = $self->{_object}->screen_file;
    ok(-s $screen_file, "Wrote screen file: $screen_file");

    # make sure we removed the conaminated amp
    my %pre_execute_amps = map { $_ => 1 } @{$self->{_pre_execute_amplicons}};
    for my $amplicon ( @{$self->amplicons} ) {
        delete $pre_execute_amps{$amplicon->get_name};
    }
    is_deeply(
        [ keys %pre_execute_amps ],
        [qw/ uyj40e03 /],
        'Removed contaminated amplicon: uyj40e03'
    );
    
    return 1;
}

###########################################################################

package Genome::Model::Tools::AmpliconAssembly::CollateTest;

use strict;
use warnings;

use base 'Genome::Model::Tools::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Tools::AmpliconAssembly::Collate';
}

sub test03_verify : Test(2) {
    my $self = shift;

    my $collate = $self->{_object};
    my @types = $collate->amplicon_assembly->amplicon_fasta_types;
    my $fasta_cnt = grep { -s $collate->amplicon_assembly->fasta_file_for_type($_) } @types;
    is($fasta_cnt, @types, 'Verified - Created a fasta for each type');
    my $qual_cnt = grep { -s $collate->amplicon_assembly->qual_file_for_type($_) } @types;
    is($qual_cnt, @types, 'Verified - Created a qual for each type');
    
    return 1;
}

###########################################################################

package Genome::Model::Tools::AmpliconAssembly::CopyFromBuild::Test;

use strict;
use warnings;

use base 'Genome::Model::Tools::AmpliconAssembly::TestBase';

use Genome::Model::Test;
use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Tools::AmpliconAssembly::CopyFromBuild';
}

sub params_for_test_class {
    return (
        directory => $_[0]->tmp_dir,
        build_id => $_[0]->_model->last_complete_build_id,
        exclude_contaminated_amplicons => 1,
        copy_reads_only => 1,
    );
}

sub _model {
    my $self = shift;

    unless ( $self->{_model} ) {
        $self->{_model} = Genome::Model::Test->create_mock_model(
            type_name => 'amplicon assembly',
            use_mock_dir => 1,
        )
            or die "Can't create mock aa model";
    }

    return $self->{_model};
}

sub should_copy_traces { 0 }
sub should_copy_edit_dir { 0 }

sub _pre_execute {
    $File::Copy::Recursive::KeepMode = 0;
    return 1;
}

sub test03_verify : Test(4) {
    my $self = shift;

    my $amplicon_assembly = Genome::AmpliconAssembly->get(directory => $self->tmp_dir);
    ok($amplicon_assembly, 'Created amplicon assembly');
    ok($amplicon_assembly->exclude_contaminated_amplicons, 'Excluding contaminated amplicons');
    ok(scalar(glob($amplicon_assembly->chromat_dir.'/*')), 'Copied reads');
    ok(!scalar(glob($amplicon_assembly->edit_dir.'/*')), 'Did not copy edit dir');
    
    return 1;
}

###########################################################################

package Genome::Model::Tools::AmpliconAssembly::Create::Test;

use strict;
use warnings;

use base 'Genome::Model::Tools::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Tools::AmpliconAssembly::Create';
}

sub params_for_test_class {
    return (
        directory => $_[0]->tmp_dir,
    );
}

sub should_copy_traces { 0 }
sub should_copy_edit_dir { 0 }

sub _pre_execute { 
    my $self = shift;

    die if -e $self->tmp_dir.'/properties.stor';
    
    return 1;
}

sub test03_verify : Test(1) {
    my $self = shift;

    ok(-e $self->tmp_dir.'/properties.stor', 'Created amplicon assembly');

    return 1;
}

###########################################################################

package Genome::Model::Tools::AmpliconAssembly::OrientTest;

use strict;
use warnings;

use base 'Genome::Model::Tools::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Tools::AmpliconAssembly::Orient';
}

sub _pre_execute {
    my $self = shift;

    my $amplicons = $self->amplicons;
    for my $amplicon ( @$amplicons ) {
        my $ori_fasta = $amplicon->oriented_fasta_file;
        unlink $ori_fasta if -e $ori_fasta;
        my $ori_qual = $amplicon->oriented_qual_file;
        unlink $ori_qual if -e $ori_qual;
    }

    my $cnt = grep { -s $_->oriented_fasta_file } @$amplicons;
    die "Did not remove oriented fastas\n" if $cnt;

    return 1;
}

sub test03_verify : Test(2) {
    my $self = shift;

    my $amplicons = $self->amplicons;
    my $fasta_cnt = grep { -s $_->oriented_fasta_file } @$amplicons;
    is($fasta_cnt, @$amplicons, 'Verified - Created oriented fasta for each amplicon');
    my $qual_cnt = grep { -s $_->oriented_qual_file } @$amplicons;
    is($qual_cnt, @$amplicons, 'Verified - Created oriented qual for each amplicon');
    
    return 1;
}

###########################################################################

package Genome::Model::Tools::AmpliconAssembly::PrepareData::Test;

use strict;
use warnings;

use base 'Genome::Model::Tools::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Tools::AmpliconAssembly::PrepareData';
}

sub should_copy_edit_dir { return; }

sub test03_verify : Test(1) {
    my $self = shift;

    my $amplicons = $self->amplicons;
    my $fasta_cnt = grep { -s $_->fasta_file } @$amplicons;
    is($fasta_cnt, @$amplicons, 'Verified - Created fasta for each amplicon');
    
    return 1;
}

###########################################################################

package Genome::Model::Tools::AmpliconAssembly::TrimAndScreenTest;

use strict;
use warnings;

use base 'Genome::Model::Tools::AmpliconAssembly::TestBase';

require File::Copy;
require File::Compare;
use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Tools::AmpliconAssembly::TrimAndScreen';
}

sub _params_for_test_class {
    return (
        trimmer_and_screener => 'trim3_and_crossmatch',
        #trimmer_and_screener_params => '-;',
    );
}

sub invalid_params_for_test_class {
    return (
        trimmer_and_screener => 'consed',
        trimmer_and_screener_params => '-;',
    );
}

sub _pre_execute {
    my $self = shift;

    my $amplicons = $self->amplicons;
    for my $amplicon ( @$amplicons ) {
        my $check_file = sprintf(
            '%s/%s.check.fasta',
            $amplicon->directory,
            $amplicon->name,
        );
        File::Copy::copy($amplicon->reads_fasta_file, $check_file)
            or die "Can't copy ".$amplicon->reads_fasta_file." to ".$check_file;
        unlink $amplicon->fasta_file;
        unlink $amplicon->qual_file;
        File::Copy::move($amplicon->reads_fasta_file, $amplicon->fasta_file)
            or die "Can't copy ".$amplicon->reads_fasta_file." to ".$amplicon->fasta_file;
        File::Copy::move($amplicon->reads_qual_file, $amplicon->qual_file)
            or die "Can't copy ".$amplicon->reads_fasta_file." to ".$amplicon->fasta_file;
    }

    return 1;
}

sub test03_verify : Test(1) {
    my $self = shift;

    my $amplicons = $self->amplicons;
    my $compare_cnt = 0;
    for my $amplicon ( @$amplicons ) {
        my $pre_fasta = sprintf(
            '%s/%s.check.fasta',
            $amplicon->directory,
            $amplicon->name,
        );
        $compare_cnt++ if File::Compare::compare($amplicon->fasta_file, $pre_fasta);
    }
    is ($compare_cnt, scalar(@$amplicons), 'Trimmed and screened amplicons');

    return 1;
}

############################################################################

package Genome::Model::Tools::AmpliconAssembly::Report::Test;

use strict;
use warnings;

use base 'Genome::Model::Tools::AmpliconAssembly::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    return 'Genome::Model::Tools::AmpliconAssembly::Report';
}

sub params_for_test_class {
    return (
        directories => [ $_[0]->tmp_dir ],
        report => 'stats',
        #report_params => '-assembly_size 1400',
        report_directory => $_[0]->tmp_dir,
        save_report => 1,
        save_datasets => 1,
        #print_report => 1,
        print_dataset => 'stats',
        #print_datasets => 1,
    );
}

sub invalid_params_for_test_class {
    return (
        report => 'none',
    );
}

sub test03_verify : Tests(3) {
    my $self = shift;

    my $dir = $self->tmp_dir;
    ok(-s $dir.'/Stats/report.xml', 'Report XML');
    ok(-s $dir.'/Stats/stats.csv', 'Stats dataset');
    ok(-s $dir.'/Stats/qualities.csv', 'Qualities dataset');
    #print "$dir\n"; <STDIN>;
    
    return 1;
}

###########
# Reports #
###########

package Genome::AmpliconAssembly::Report::TestBase;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
require Genome::Model::Test;
use Test::More;

sub required_params_for_class {
    return;
}

sub generator {
    return $_[0]->{_object};
}

sub report_name {
    my $self = shift;

    my ($pkg) = $self->test_class =~ m/Genome::Model::AmpliconAssembly::Report::(\w+)$/;

    return 'Test '.$pkg.' Report',
}

sub params_for_test_class {
    return (
        amplicon_assemblies => [ $_[0]->mock_model->last_succeeded_build->amplicon_assembly ],
        $_[0]->_params_for_test_class,
    );
}

sub _params_for_test_class {
    return;
}

sub mock_model {
    my $self = shift;

    unless ( $self->{_mock_model} ) {
        $self->{_mock_model} = Genome::Model::Test->create_mock_model(
            type_name => 'amplicon assembly',
            use_mock_dir => 1,
        );
    }
    
    return $self->{_mock_model};
}

sub test01_generate_report : Test(2) {
    my $self = shift;

    can_ok($self->generator, '_add_to_report_xml');

    use Carp;
    $SIG{__DIE__} = sub{ confess(@_); };
    
    my $report = $self->generator->generate_report;
    ok($report, 'Generated report');

    return 1;
}

######################################################################

package Genome::AmpliconAssembly::Report::Compare::Test;

use strict;
use warnings;

use base 'Genome::AmpliconAssembly::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    'Genome::AmpliconAssembly::Report::Compare';
}

sub params_for_test_class {
    return (
        amplicon_assemblies => [ $_[0]->mock_model->last_succeeded_build->amplicon_assembly,
        $_[0]->mock_model->last_succeeded_build->amplicon_assembly,
        ],
    );
}

sub invalid_params_for_test_class {
    return (
    );
}

sub test01_ {# : Tests(2) {
    my $self = shift;

    return 1;
}

######################################################################

package Genome::AmpliconAssembly::Report::Stats::Test;

use strict;
use warnings;

use base 'Genome::AmpliconAssembly::Report::TestBase';

use Data::Dumper 'Dumper';
use Test::More;

sub test_class {
    'Genome::AmpliconAssembly::Report::Stats';
}

sub _params_for_test_class {
    return (
    );
}

sub invalid_params_for_test_class {
    return (
    );
}

sub test02_position_quality_stats : Tests(2) {
    my $self = shift;

    my $qual = $self->{_object}->get_position_quality_stats;
    #print Dumper($qual->{position_qualities});
    ok($qual, 'Quality stats');
    is(scalar(keys %{$qual->{position_qualities}}), 3, 'Read counts');

    return 1;
}

sub test03_assembly_stats : Tests(1) {
    my $self = shift;

    my $stats = $self->{_object};
    my $assembly_stats = $stats->get_assembly_stats;
    #print Dumper($assembly_stats);
    is_deeply(
        $assembly_stats, {
            headers => [qw/ assembled assemblies-with-3-reads assemblies-with-5-reads assemblies-with-6-reads assemblies-with-zeros assembly-success attempted length-average length-maximum length-median length-minimum quality-base-average quality-less-than-20-bases-per-assembly reads reads-assembled reads-assembled-average reads-assembled-maximum reads-assembled-median reads-assembled-minimum reads-assembled-success /],
            stats => [qw/ 5 3 1 1 2 100.00 5 1399 1413 1396 1385 62.75 1349.80 30 20 4.00 6 3 3 66.67 /],
        },
        'Assembly stats',
    );

    return 1;
}

sub test04_none_attempted : Tests(2) {
    my $self = shift;

    my $stats = $self->{_object};
    $stats->{_metrix}->{assembled} = 0;
    my $assembly_stats = $stats->get_assembly_stats;
    is_deeply(
        $assembly_stats, {
            headers => [qw/ assembled attempted assembly-success /],
            stats => [qw/ 0 5 0.00 /],
        },
        'Assembly stats w/ none assembled',
    );

    my $qual = $stats->get_position_quality_stats;
    ok($qual, 'Position quality stats w/ none assembled');

    return 1;
}

sub test05_none_attempted : Tests(1) {
    my $self = shift;

    my $stats = $self->{_object};
    $stats->{_metrix}->{attempted} = 0;  
    ok(!$stats->get_assembly_stats, 'Failed as expected - no assemblies attempted');
    
    return 1;
}

######################################################################

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

