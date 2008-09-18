package Genome::Model::Tools::ManualReview::ViewWithConsed;

use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use Genome;

use GSCApp;
#use GSCApp::Test qw/no_plan/ ;


my ($ace_suffix, $review,$list);
my $consed= 'cs';
my $relative_target_base_pos;
class Genome::Model::Tools::ManualReview::ViewWithConsed {
    is => "Command",
    has => [
        ace_suffix => {
            type => 'String',
            doc => "version suffix of reviewed ace file",
            is_optional => 1,            
        },
        review => {
            type => 'Boolean',
            doc => "allow user to update the review category",
            is_optional => 1,
        },
        main_contig_pos => {
            type => 'Int',
            doc => "the position to scroll consed to when opening the contig",
            is_optional => 1,
        },
        review_directory => {
            type => 'String',
            doc => "directory of manual review tree",
            is_optional => 1,
        }
    ]
};

sub help_brief {
    "usage: gt manual-review view-with-consed --ace <ace or 1 or 2 default is 1> feed_batch_consed_file" 
}

STDOUT->autoflush(1);
App->init;

sub execute
{
    my $self = shift;
    my $ace_suffix = $self->ace_suffix;
    my $review = $self->review || 0;
    my $relative_target_base_pos = $self->main_contig_pos || 300;
    chdir($self->review_directory) if ($self->review_directory);
    #my $arch = `uname -m`;
    #chomp $arch;

    my $suffix = ($ace_suffix)? "." .$ace_suffix : ".1";
    $suffix = '' if $suffix eq '.ace';
    my $i=0;
    my $base = `pwd`;
    chomp $base;

    my $tumorW_dir = "$base/tumorWildType";
    my $tumorV_skinW_dir = "$base/tumorVariant_skinWildType";
    my $tumorV_skinV_dir = "$base/tumorVariant_skinVariant";
    my $tumorV_skinU_dir = "$base/tumorVariant_skinUnknown";
    my $tumorV_maybe_dir = "$base/tumorVariant_maybe";

    my @all_dirs =($tumorW_dir, $tumorV_skinW_dir, $tumorV_skinV_dir, $tumorV_skinU_dir, $tumorV_maybe_dir);
    if($review){
        for($tumorW_dir, $tumorV_skinW_dir, $tumorV_skinV_dir, $tumorV_skinU_dir, $tumorV_maybe_dir){
            unless(-d $_){
                mkdir $_ or die "can't mkdir $_";
            }
        }
    }

    my @dirs;

    if($list){
        open F, $list or die "can't open $list";
        while(<F>){
            chomp;
            push @dirs, $_;
        }
    }else{
        opendir DIR, $base or die "can't open $base";

        while( my $d =readdir(DIR)){
            next if $d =~ /^\./;
            next if grep {$d eq $_} @all_dirs;
            if(-d $d){
                push @dirs, $d;
            }else{
                print "Not a directory: $d\n";
            }
        }
    }

    for(@dirs){
        chomp;
        s/\/$//;
        my($file, $dir)= fileparse($_);

        my ($seqid, $pos) = $file =~ /(\d+)_(\d+)/;
        $relative_target_base_pos = 300;#$pos-1;
        my $edit_dir = "$base/$_/edit_dir";
        if( -d $edit_dir){
            chdir $edit_dir or die "can't cd to $edit_dir"; 

            my $ace1 = "$file.ace$suffix";
            unless(-e $ace1){
                print "ERROR no: $ace1 ... skipping (report to sabbott)\n"; 
                next;
            }
            $i++;
            print $i. ") $file ... open/skip o/s [o] ";
            my $input = <STDIN>;
            chomp $input;
            if($input =~ /^s/i){
                next;
            }

            $self->error_message("Failed to set consed project rc.\n") and return
            unless set_project_consedrc($edit_dir);
            
            my $c_command= "$consed -ace $ace1 -mainContigPos $relative_target_base_pos &> /dev/null";

            $self->error_message("Failed to launched consed.\n") and return 
            if system($c_command);

            if($review){
                my $command;
                print "What was the result:\n".
                "[w]tumorWildType, [m]tumorMaybe, [s]tumorVariant_skinWild, [g]tumorVariant_skinVariant, [u]tumorVariant_skinUnknown ";
                $_=<STDIN>;
                chomp;
                if(/^w/i){
                   $command= "mv $base/$file $tumorW_dir"; 
                }elsif(/^s/i){
                   $command= "mv $base/$file $tumorV_skinW_dir"; 
                }elsif(/^g/i){
                   $command= "mv $base/$file $tumorV_skinV_dir"; 
                }elsif(/^u/i){
                   $command= "mv $base/$file $tumorV_skinU_dir"; 
                }elsif(/^m/i){
                   $command= "mv $base/$file $tumorV_maybe_dir"; 

                }else{
                    print "skipping action\n";
                }

                if($command){
                    print "$command\n";
                    system($command);
                }
            }
        }else{
            $self->error_message("ERROR  Can't find $edit_dir ... skipping (report to sabbott)\n");
        }
    }
    return 1;
}


sub set_project_consedrc {
    my $edit_dir =shift;
    my $rc ="$edit_dir/.consedrc";

    my $wide = 'consed.alignedReadsWindowInitialCharsWide: 120';
    my $expand = 'consed.alignedReadsWindowAutomaticallyExpandRoomForReadNames: false';

    my %rc_hash;
    my $i;
    if(-e $rc ){
        open F, $rc or self->error_message("Failed to open consed rc ($rc).\n") and return; 
        while(<F>){
            chomp;
            $i++;
            $rc_hash{$_}=$i;
        }
        close F;

    }

    my @to_append;
    unless(exists $rc_hash{$wide}){
        push @to_append, $wide;
    }
    unless(exists $rc_hash{$expand}){
        push @to_append, $expand;
    }

    return unless @to_append;

    open F, ">>$rc" or self->error_message("Failed to open consed rc ($rc).\n") and return; 
    for(@to_append){
        print F $_ ."\n";
    }
    close F;

    return 1;
}
1;
    
