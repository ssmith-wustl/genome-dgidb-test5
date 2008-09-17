package Genome::Model::Tools::CreateManualReviewDirectory;
use strict;
use warnings;
use Command;
use Data::Dumper;
use IO::File;
use PP::LSF;
use File::Temp;
use File::Basename;
class Genome::Model::Tools::CreateManualReviewDirectory
{
    is => 'Command',                       
    has => 
    [ 
        map_list => 
        {
            type => 'String',
            is_optional => 0,
            doc => "File of input maps",
        },
        snp_file =>
        {
            type => 'String',
            is_optional => 0,
            doc => "File of variants",    
        },
        output_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "Directory to generate Manual Review reports",    
        }
    ], 
};
############################################################
sub help_brief {   
    return;
}
sub help_synopsis { 
    return;
}
sub help_detail {
    return <<EOS 
    Creates a manual review directory from a given map list, snp file, and output dir.  The user is required to
    do job monitoring as there is no automated job monitoring in this version.  So, you must rerun this
    command three times, with the appropriate step specified in the step argument.  There are three steps.
    In step 0, intersects of the supplied maps are performed.  In step 1, those intersected map files are 
    merged, and this merge file is written to the output_dir.  In step 2, a tree containing the intersected
    map files and their read lists is created in the output_dir. 
EOS
}
############################################################
sub execute { 
    my $self = shift;
    my $out_dir = $self->output_dir;
    
    my $snps = $self->snp_file;
    my $maplist = $self->map_list;
    $DB::single = 1;
    #unless(`uname -m` =~ /x86_64/)
    #{
    #    $self->error_message( "manual-review must be run on a x64 system.\n");
    #    return 0;
    #}
    
    if(!-e $out_dir) {`mkdir -p $out_dir`;}
    my $gt = `which gt`;
    chomp($gt);
    my $fh = IO::File->new($maplist);
    my @lines = <$fh>;
    chomp @lines;
    my @jobs;

    if(!-e "$out_dir/all.map")
    {
        `mkdir -p $out_dir/temp_map`;
        foreach my $line (@lines)
        {
            my $l = basename($line);
            my $f = $line;
            my $o = $f;
            
            $o = $out_dir."/temp_map/".$l;
            print $o,"\n";
            die "File $o alreadys exists!\n" if(-e $o);
            #system("bsub -q aml -oo $l.log gt maq get-intersect --input=$f --snpfile=$snps --output=$o");
            my %job_params = (
                pp_type => 'lsf',
                q => 'short',
                command => "$gt maq get-intersect --input=$f --snpfile=$snps --output=$o",
                o => "$l.log",
            );
            my $job = PP::LSF->create(%job_params);
            $self->error_message("Can't create job: $!")
                and return unless $job;
            push @jobs, $job;            
        }
        
        foreach(@jobs)
        {
            $_->start;
        }
        while(1)
        {
            foreach(@jobs)
            {
                if(defined $_ && $_->has_ended){
                    if($_->is_successful) {$_ = undef;}
                    else {die "Job failed.\n"}                    
                }
            }
            foreach(@jobs)
            {
                if(defined $_) { goto SLEEP;}
            }
            last; #if we're here then we're done
SLEEP:      sleep 30;
        }
    }
    if(!-e "$out_dir/all.map")
    {
        @jobs = ();
        foreach (@lines) 
        {
            $_ = $out_dir."/temp_map/".basename($_);
        }
        my $maps = join ' ',@lines;       
        #system("bsub -q aml -R 'select[type=LINUX64]'-oo mapmerge.log maq mapmerge $out_dir/all.map $maps");
        my %job_params = (
                pp_type => 'lsf',
                q => 'short',
                R => 'select[type=LINUX64]',
                command => "maq mapmerge $out_dir/all.map $maps",
                oo => "mapmerge.log",
            );
        my $job = PP::LSF->create(%job_params);
        $self->error_message("Can't create job: $!")
            and return unless $job;
        $job->start;
        while(1)
        {
            if($job->has_ended){
                if($job->is_successful) {last;}
                else {die "Job failed.\n";}                    
            }
            sleep 30;
        }            
    }
    if(1)
    {
        @jobs = ();
        $fh = IO::File->new($snps);    
        foreach my $line (<$fh>)
        {
            chomp $line;
            my ($seq, $pos) = split /\s+/,$line; 
            my $seqpos = $seq.'_'.$pos;
            if(!-e "$out_dir/$seqpos"){`mkdir -p $out_dir/$seqpos`;}
            my $temp_fh = IO::File->new(">$out_dir/$seqpos/annotation.tsv");
            print $temp_fh $line,"\n"; 
        }
        $fh->seek(0,0);
        foreach my $line (<$fh>)
        {   
            chomp $line;
            my ($seq, $pos) = split /\s+/,$line; 
            my $seqpos = $seq.'_'.$pos;
            #system("bsub -q aml -W 50 -oo $seqpos.log gt maq get-intersect --input=$out_dir/all.map --snpfile=$out_dir/$seqpos/annotation.tsv --output=$out_dir/$seqpos/$seqpos --justname=2");
            my %job_params = (
                pp_type => 'lsf',
                q => 'short',
                W => 5,
                command => "$gt maq get-intersect --input=$out_dir/all.map --snpfile=$out_dir/$seqpos/annotation.tsv --output=$out_dir/$seqpos/$seqpos --justname=2",
                oo => "$seqpos.log",
            );
            my $job = PP::LSF->create(%job_params);
            $self->error_message("Can't create job: $!")
                and return unless $job;
            push @jobs, $job; 
        }
        foreach(@jobs)
        {
            $_->start;
        }
        
        while(1)
        {
            foreach(@jobs)
            {
                if(defined $_ && $_->has_ended){
                    if($_->is_successful) {$_ = undef;}
                    else {die "Job failed.\n"}                    
                }
            }
            foreach(@jobs)
            {
                if(defined $_) { goto SLEEEP;}
            }
            last; #if we're here then we're done
SLEEEP:      sleep 30;
        }
        `rm -rf $out_dir/temp_map`;        
    }
    @jobs = ();
    
    my $proj_fof = File::Temp->new(UNLINK => 1);
    my @projects = `\\ls -d -1 $out_dir/*/`;
    
    print $proj_fof @projects;
    #print $out_dir,"\n",$proj_fof,"\n";
    
    $proj_fof->close;    
    #return Genome::Model::Tools::PrepareNextgenAce->execute(fof => $proj_fof->filename, basedir => $out_dir);
    foreach my $line (@projects)
    {   
        chomp $line;

        my %job_params = (
            pp_type => 'lsf',
            q => 'short',
            W => 5,
            command => "$gt prepare-nextgen-ace --project-dir=$line --basedir=$out_dir",
            oo => "$line.log",
        );
        my $job = PP::LSF->create(%job_params);
        $self->error_message("Can't create job: $!")
            and return unless $job;
        push @jobs, $job; 
    }
    foreach(@jobs)
    {
        $_->start;
    }

    while(1)
    {
        foreach(@jobs)
        {
            if(defined $_ && $_->has_ended){
                if($_->is_successful) {$_ = undef;}
                else {$self->error_message( "Job failed.\n"); return;}                    
            }
        }
        foreach(@jobs)
        {
            if(defined $_) { goto SLEEEEP;}
        }
        last; #if we're here then we're done
SLEEEEP:      sleep 30;
    }
    return 1;
}
############################################################
1;
