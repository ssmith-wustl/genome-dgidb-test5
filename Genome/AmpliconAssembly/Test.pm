###########################################################################

package Genome::AmpliconAssembly::Test;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use Test::More;
require File::Path;

use Data::Dumper 'Dumper';

sub test_class {
    return 'Genome::AmpliconAssembly';
}

sub amplicon_assembly {
    return $_[0]->{_object};
}

sub params_for_test_class {
    my $self = shift;
    return (
        directory => $self->base_test_dir.'/Genome-Model-AmpliconAssembly/build-10000',
    );
}

sub invalid_params_for_test_class {
    return (
        sequencing_center => 'washu',
        sequencing_platform => '373',
    );
}

sub test_01_amplicons_gsc_3730 : Tests {
    my $self = shift;
    
    # amplicons
    my $amplicon_assembly = $self->amplicon_assembly;
    my $amplicons = $amplicon_assembly->get_amplicons;
    is(@$amplicons, 5, 'got 5 amplicons');

    # reads for amplicon
    my @reads = $self->amplicon_assembly->get_all_amplicons_reads_for_read_name(
        ($amplicons->[0]->reads)[0],
    );
    is_deeply(\@reads, $amplicons->[0]->get_reads, 'Got all amplicons reads for read name');
    
    return 1;
}

# TODO sub test_02_amplicons_broad_3730 : Tests {

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
use Genome::Model::AmpliconAssembly::Test; # necessary cuz mock objects are in here
use Test::More;

sub params_for_test_class {
    return (
        directory => $_[0]->tmp_dir,
        $_[0]->_params_for_test_class,
    );
}

sub amplicons {
    return $_[0]->{_object}->get_amplicons;
}

sub _params_for_test_class { return; }
sub should_copy_traces { 1 }
sub should_copy_edit_dir { 1 }
sub _pre_execute { 1 }

sub test_01_copy_data : Tests {
    my $self = shift;

    if ( $self->should_copy_traces ) {
        ok( 
            Genome::Model::AmpliconAssembly::Test->copy_test_dir(
                'chromat_dir',
                $self->{_object}->chromat_dir,
            ),
            "Copy traces"
        ) or die;
    }

    if ( $self->should_copy_edit_dir ) {
        ok(
            Genome::Model::AmpliconAssembly::Test->copy_test_dir(
                'edit_dir',
                $self->{_object}->edit_dir,
            ),
            "Copy edit_dir"
        ) or die;
    }

    return 1;
}

sub test_02_execute : Test(2) {
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

sub should_copy_edit_dir { 0 }

sub test_03_verify : Test(1) {
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

sub test_03_verify : Test(1) {
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
        my $dh = Genome::Utility::FileSystem->open_directory($source)
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

sub test_03_verify : Test(2) {
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

sub test_03_verify : Test(2) {
    my $self = shift;

    my $amplicons = $self->amplicons;
    my $fasta_cnt = grep { -s $_->oriented_fasta_file } @$amplicons;
    is($fasta_cnt, @$amplicons, 'Verified - Created oriented fasta for each amplicon');
    my $qual_cnt = grep { -s $_->oriented_qual_file } @$amplicons;
    is($qual_cnt, @$amplicons, 'Verified - Created oriented qual for each amplicon');
    
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

sub test_03_verify : Test(2) {
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

1;

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

