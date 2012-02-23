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
        $self->{_amplicon_assembly} = Genome::Model::Tools::AmpliconAssembly::Set->create(
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

    my $amplicon_assembly = Genome::Model::Tools::AmpliconAssembly::Set->get(directory => $self->tmp_dir);
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

1;

