package Genome::Model::Tools::Assembly::Repair::AutoJoin;
use strict;
use warnings;
use IO::File;
use Data::Dumper;
use File::Basename;

use Finishing::Assembly::Factory;
use Finishing::Assembly::ContigTools;
use Finishing::Assembly::PhdDB;
use Finishing::Assembly::Phd::FastaAndQualDB;
use Finishing::Assembly::Phd;
use Finishing::Assembly::Ace::Exporter;

use Alignment::SequenceMatch::Blast;
#use ProjectWorkBench::Model::Ace;
use Cwd;
use GSCApp;
use Sys::Hostname;
use Sort::Naturally;
use Date::Format;

class Genome::Model::Tools::Assembly::Repair::AutoJoin
{
    is => 'Command',                       
    has => 
    [
    ace =>
    {
        type => 'String',
        is_optional => 0,
        doc => "input ace file"        
    },
#    assembler =>
#    {
#        type => 'String',
#        is_optional => 0,
#        doc => "assembler that created the ace file"
#    },
    min_length =>
    {
        type => 'String',
        is_optional => 1,
        doc => "minimum match length"        
    }, 
    max_length =>
    {
        type => 'String',
        is_optional => 1,
        doc => "maximum crossmatch length"        
    },
    min_read_num =>
    {
        type => 'String',
        is_optional => 1,
        doc => "minimum number of reads to support joins"        
    },
    cm_segments =>
    {
        type => 'String',
        is_optional => 1,
        doc => "Length of sequences at each ends to run cross match"        
    },
    cm_min_match =>
    {
        type => 'String',
        is_optional => 1,
        doc => "Minimum length of cross match to consider for join"        
    },
    ], 
};
#############################################################


sub execute
{
    my $self = shift;
    my $ace_in = $self->ace;

#    my $min_length = $self->min_length;
#    my $max_length = $self->max_length;
#    my $min_read_num = $self->min_read_num;
#    my $cm_seg = $self->cm_segments;
#    my $cm_min_match = $self->cm_min_match;

    my $log_fh = IO::File->new(">$ace_in".'_autojoins.log');

    #TODO: check to make sure phd file is there

    #exclude contigs that are less than this bp
#    $min_length = 100 unless $min_length;
    #exclude contigs that are more than this bp
#    $max_length = 10000000 unless $max_length;
    #exclude contigs with less than this number of reads
#    $min_read_num = 2 unless $min_read_num;
    #number of bases to consider in running cross_match
#    $cm_seg = 500 unless $cm_seg;
    #minimum cross match
#    $cm_min_match = 25 unless $cm_min_match;

    my $time;

    #cat all the phdball files together since we can only
    #load one file

    my $done = $self->cat_all_phdballs ();

    #ace file DS lines has to be modified for reads to
    #properly link with phdball
    my $auto_ace = $self->add_phd_to_ace_DS_line ($ace_in);

    #get contig info hash
    #see if it dosn't make much difference to hand over ace_obj
    #and keep that in memory thoughout the run

    $time = time2str('%y%m%d:%H%M%S', time);
    print "Please wait gathering contig info: $time\n";
    $log_fh->print ("Please wait gathering contig info: $time\n");
    my ($contigs_info, $ctgs_list) = $self->get_contigs_info ($auto_ace);
    #print Dumper $contigs_info;
    #print Dumper $ctgs_list;

    #parse through contig info hash and create array key of
    #scaffolding congigs for each contig
    $time = time2str('%y%m%d:%H%M%S', time);
    print "Please wait gathering scaffold info: $time\n";
    $log_fh->print("Please wait gathering scaffold info: $time\n");
    my $ctg_scaf_hash = $self->gather_scaf_info ($contigs_info, $ctgs_list);
    #print Dumper $ctg_scaf_hash;

    #print out ends of contigs for cross_match
    $time = time2str('%y%m%d:%H%M%S', time);
    print "Please wait gathering sequences to run cross_match: $time\n";
    $log_fh->print("Please wait gathering sequences to run cross_match: $time\n");
    my $cm_output_file = $self->print_out_ctg_ends ($auto_ace, $ctg_scaf_hash);

    #run cross_match
    $time = time2str('%y%m%d:%H%M%S', time);
    print "Pleae wait running cross_match: $time\n";
    $log_fh->print("Pleae wait running cross_match: $time\n");
    my $cm_out = $self->run_cross_match ($cm_output_file, $auto_ace);

    #parse cross_match out file and get joins
    $time = time2str('%y%m%d:%H%M%S', time);
    print "Please wait parsing cm output file: $time\n";
    $log_fh->print("Please wait parsing cm output file: $time\n");
    #pre-join hash
    my $pj_hash = $self->parse_cross_match_file ($cm_out, $ctg_scaf_hash);
    #print Dumper $pj_hash;

    $time = time2str('%y%m%d:%H%M%S', time);
    print "Please wait looking for joins: $time\n";
    $log_fh->print("Please wait looking for joins: $time\n");
    my $joins_hash = $self->find_joins ($pj_hash);
    #print Dumper $joins_hash;

    $pj_hash = ''; #save memory

    $time = time2str('%y%m%d:%H%M%S', time);
    print "Please wait aligning joins: $time\n";
    $log_fh->print("Please wait aligning joins: $time\n");
    my $new_scafs = $self->align_joins ($joins_hash);
    #print Dumper $new_scafs;

    $self->print_new_scafs ($new_scafs, $auto_ace); #if user wants to
    #print and exit if reports only  .. 

    $time = time2str('%y%m%d:%H%M%S', time);
    print "Please wait making joins: $time\n";
    $log_fh->print("Please wait making joins: $time\n");
    my $merged_ace = $self->make_joins ($new_scafs, $auto_ace, $log_fh);

    unlink $auto_ace;

    my $qa_fixed_ace = $self->fix_ace_qa_line ($merged_ace);

    unlink $merged_ace;

    my $new_tags_ace = $self->clean_up_tags ($qa_fixed_ace);

    unlink $qa_fixed_ace;
    #need to fix DS line again .. add in VERSION: 1

    my $final_ace = $self->add_version_to_DS_line ($new_tags_ace);

    unlink $new_tags_ace;

    #need to add wa_tags to load phd balls

    $final_ace = $self->add_WA_tags_to_ace ($final_ace);

    $time = time2str('%y%m%d:%H%M%S', time);
    print "Done, $time\n";
    $log_fh->print("Done: $time\n");
    $log_fh->close;

    return 1;
}



sub cat_all_phdballs
{
    my $self = shift;
    my $dir = cwd();

    my $phdball_dir = $dir.'/../phdball_dir';

    my $autojoin_ball_name = 'autoJoinPhdBall';

    return 1 if -s $phdball_dir.'/'.$autojoin_ball_name;

    if (-d $phdball_dir)
    {
        my @ball_files = glob ("$phdball_dir/*phdball");

        if (scalar @ball_files > 0)
        {
            my $ec = `touch autoJoinPhdBall`;
            print "Cannot create autoJoinPhdBall file\n" and exit (1) if $ec;
            foreach my $ball_file (@ball_files)
            {
                my $ec = `cat $ball_file >> $phdball_dir/autoJoinPhdBall`;
                print "Cannot cat $ball_file to autoJoinPhdBall\n" and exit (1) if $ec;
            }

        }
    }

    #METHOD JUST RETURNS 1 IF NO PHDBALL FILES ARE PRESENT 
    #OR IF PHDBALL DIR DOES NOT EXIST .. ASSUMING THEY'ARE NOT
    #THERE BECAUSE THEY'RE NOT NEEDED

    return 1;
}

sub add_WA_tags_to_ace
{
    my ($self, $ace) = @_;
    my $fh = IO::File->new(">> $ace") || die "Cannot create filehandle for $ace";
    my $dir = cwd();
    my $ball_dir = $dir;
    $ball_dir =~ s/edit_dir$/phdball_dir/;
    if (-d $ball_dir)
    {
        my @phdball_files = glob ("$ball_dir/*phdball");
        if (scalar @phdball_files > 0)
        {
            chomp (my $date = `date '+%y%m%d:%H%M%S'`);
            #this is crazy but for some reason this doesn't work with current date .. eg 090129:160913
#	    my $date = '080416:144002';
            foreach my $ball_file (@phdball_files)
            {
                my $tag = "\nWA{\nphdBall newbler $date\n$ball_file\n}\n";
                $fh->print($tag);
            }
        }
    }
    $fh->close;
    return $ace;
}

sub add_version_to_DS_line
{
    my ($self, $ace) = @_;

    my $ace_in = $self->ace;
    my $ace_out = $ace_in.'.final';
    my $fh = IO::File->new("< $ace") || die "Cannot open file: $ace";
    my $out_fh = IO::File->new (">$ace_out") || die "Cannot create file handle: $ace_out";
    while (my $line = $fh->getline)
    {
        if ($line =~ /^DS\s+/)
        {
            chomp $line;
            if ($line =~ /\.sff\:/ and $line =~ /PHD_FILE\:\s+\S+/)
            {
                $line =~ s/^DS /DS VERSION: 1 /;
                $line =~ s/PHD_FILE\:\s+\S+\s+//;
                $line .= ' CHEM: 454';
                $out_fh->print($line."\n");
                next;
            }
            $out_fh->print($line."\n");
            next;
        }
        $out_fh->print($line);
    }
    $fh->close;
    $out_fh->close;
    return $ace_out;
}

sub add_phd_to_ace_DS_line
{
    my ($self, $ace) = @_;
    my $ace_out = $ace.'.DS_line_fixed';
    my $fh = IO::File->new("< $ace") || die "Cannot read file: $ace";
    my $out_fh = IO::File->new("> $ace_out") || die "Cannot create file handle: $ace_out";
    my $read_name;
    while (my $line = $fh->getline)
    {
        if ($line =~ /^RD\s+/)
        {
            ($read_name) = $line =~ /^RD\s+(\S+)/;
            $out_fh->print($line);
            next;
        }
        if ($line =~ /^DS\s+/)
        {
            if ($line =~ /PHD_FILE\:\s+/)
            {
                $out_fh->print($line);
                next;
            }
            chomp $line;
            $line .= " PHD_FILE: $read_name\n";
            $out_fh->print($line);
            next;
        }
        $out_fh->print($line);
    }

    $fh->close;
    $out_fh->close;

    return $ace_out;
}

sub make_joins
{
    my ($self, $scafs, $ace, $log_fh) = @_;

    my $dir = cwd();

    print "Please wait: gathering phds and ace file .. this could take up to 10 minutes\n";

    my $ctg_tool = Finishing::Assembly::ContigTools->new;

    my $fo = Finishing::Assembly::Factory->connect('ace', $ace);
    my $ace_obj = $fo->get_assembly;

    my $ace_out = $ace.'.autojoined';
    my $xport = Finishing::Assembly::Ace::Exporter->new( file => $ace_out );

    my @phd_objs;

    my $phd_dir = "$dir/../phd_dir";
    print "Invalid phd directory: $phd_dir\n" and exit (1) unless -d $phd_dir;

    my $phd_obj = Finishing::Assembly::Phd->new(input_directory => "$dir/../phd_dir");
    print "Cannot create phd_dir object\n" and exit (1) unless $phd_obj;

    push @phd_objs, $phd_obj;

    my $phd_ball = "$dir/../phdball_dir/autoJoinPhdBall";

    if (-s $phd_ball)
    {
        my $phd_ball_obj = Finishing::Assembly::Phd::Ball->connect(ball => $phd_ball);
        print "Cannot create phd_ball_obj\n" and exit (1) unless $phd_ball_obj;

        push @phd_objs, $phd_ball_obj;
    }
    #create a temp hash to keep track of contigs not joined
    my %unused_contig_names;
    foreach ($ace_obj->contigs->all)
    {
        $unused_contig_names{$_->name} = 1;
    }

    my $join_count = 0;
    my $ace_version = 0;

    foreach my $line (@$scafs)
    {
        #new scaf number?
        #scaffold name is really the first contig name

        my ($new_scaf_name) = $line =~ /^New\s+scaffold:\s+(\d+\.\d+)/;
        $new_scaf_name = 'Contig'.$new_scaf_name;

        $line =~ s/^New\s+scaffold:\s+(\d+\.\d+)\s+//;
        my @ctgs = split (/\s+\<-\d+-\>\s+/, $line);

        my $next_ctg = shift @ctgs;

        #accepts (1.1) or 1.1 and returns the following
        #Contig1.1, yes for (1.1) and
        #Contig1.1, no for 1.1

        my ($left_ctg_name, $left_comp) = $self->resolve_complementation ($next_ctg);

        my $left_ctg_obj = $ace_obj->get_contig ($left_ctg_name);
        print "Cannot get left contig obj\n" and exit (1) unless $left_ctg_obj;
        print "Complementing left " and $left_ctg_obj->complement if $left_comp eq 'yes';

        while (scalar @ctgs > 0)
        {
            #if merge fails grab the next two contigs and start a new scaffold
            #otheriwse just grab the next contigs and join to the current scaffold

            $next_ctg = shift @ctgs;
            my ($right_ctg_name, $right_comp) = $self->resolve_complementation ($next_ctg);
            print "Right ctg name: $right_ctg_name, comp: $right_comp\n";

            my $right_ctg_obj = $ace_obj->get_contig ($right_ctg_name);
            print "Cannot get right ctg obj\n" and exit (1) unless $right_ctg_obj;
            $right_ctg_obj->complement if $right_comp eq 'yes';

            eval {
                $left_ctg_obj = $ctg_tool->merge($left_ctg_obj, $right_ctg_obj, undef, phd_array => \@phd_objs);
            };

            if ($@)
            {
                print "\n\nMERGE FAILED\n\n";
                exit (0);
                #need to do something if join fails .. like start a new scaffold
            }

            $log_fh->print("Joined $left_ctg_name, $right_ctg_name\n");

            foreach ($left_ctg_name, $right_ctg_name)
            {
                delete $unused_contig_names{$_} if exists $unused_contig_names{$_};
            }
        }

        $xport->export_contig(contig => $left_ctg_obj, new_name => $left_ctg_name);
    }

    #need to export all the unused contigs
    if (scalar keys %unused_contig_names > 0)
    {
        foreach (keys %unused_contig_names)
        {
            my $contig_obj = $ace_obj->get_contig($_);
            $xport->export_contig(contig => $contig_obj);
        }
    }

    $xport->close;

    return $ace_out;
}

sub resolve_complementation
{
    my ($self, $contig_number) = @_;
    return 'Contig'.$contig_number, 'no' unless $contig_number =~ /\(\S+\)/;
    ($contig_number) = $contig_number =~ /\((\S+)\)/;
    return 'Contig'.$contig_number, 'yes';
}

sub print_new_scafs
{
    my ($self, $scafs, $ace) = @_;
    my $new_scaffold_out_file = $ace.'_auto_joins_new_scaffolds.txt';
    my $fh = IO::File->new(">$new_scaffold_out_file");
    print "Unable to create autojoins new scaffolds file\n" and return unless $fh;
    $fh->print (map {$_."\n\n"} @$scafs);
    $fh->close;
    return 1;
}

sub align_joins
{
    my ($self, $h) = @_;
    my @new_scafs;
    foreach my $scaf (nsort keys %$h)
    {
        print ("New scaffold: $scaf\n");
        my $txt = "New scaffold: $scaf ";
        if (exists $h->{$scaf}->{left})
        {
            my $count = scalar @{$h->{$scaf}->{left}};
            my $i = 0;
            until ($i == $count)
            {
                my $ctg = pop @{$h->{$scaf}->{left}};
                my $overlap = ' <-'.$ctg->{overlap}.'-> ';
                my $contig = $ctg->{name};

                $contig = "($ctg->{name})" if $ctg->{dir} eq 'left';

                #If contig is less than 500 bp and it's not complemented
                #relative to the contig it hit to then there's no need
                #to complement the contig
                if ($ctg->{length} < 201 and $ctg->{is_comp} eq 'no')
                {
                    $contig = $ctg->{name};
                }

#		$contig = "($ctg->{name})" if $ctg->{dir} eq 'left';
                print ($contig.$overlap);
                $txt .= $contig.$overlap;
                $i++;
            }
        }
        print ($scaf);
        $txt .= $scaf;
        if (exists $h->{$scaf}->{right})
        {
            foreach my $ctg (@{$h->{$scaf}->{right}})
            {
                my $overlap = ' <-'.$ctg->{overlap}.'-> ';
                my $contig = "$ctg->{name}";
                $contig = "($ctg->{name})" if $ctg->{dir} eq 'right';

                #If contig is less than 500 bp and it's not complemented
                #relative to the contig it hit to then there's no need
                #to complement the contig
                if ($ctg->{length} < 201 and $ctg->{is_comp} eq 'no')
                {
                    $contig = $ctg->{name};
                }
                print ($overlap.$contig);
                $txt .= $overlap.$contig;
            }
        }
        print ("\n");
        push @new_scafs, $txt;
    }
    return \@new_scafs;
}

sub find_joins
{
    my ($self, $pj_hash) = @_;
    my $join_small_contigs = 'yes';
    my $join_major_contigs = 'yes';
    my $joins = {};
    my @joined;

    my $continue = 'yes';

    if ($join_major_contigs eq 'yes')
    {
        foreach my $ctg (nsort keys %$pj_hash)
        {
            next if $pj_hash->{$ctg}->{is_scaffold} eq 'no';
            next if grep (/^$ctg$/, @joined);

            push @joined, $ctg;

            #split contig number from scaffold contig name
            #then look for next scaffold
            my ($scaf_name, $ctg_num) = $ctg =~ /^(\d+)\.(\d+)$/;
            $ctg_num++;

            my $next_scaf_ctg = $scaf_name.'.'.$ctg_num;
            my $h = {};

            #this is the first ctg in scaffold, build the left end
            if ($ctg =~ /^\d+\.1$/)
            {
                if (exists $pj_hash->{$ctg}->{left})
                {
                    #look at the left end of first_scaf_ctg and make joins
                    my $longest_overlap = 0;
                    my $hh;
                    foreach my $match_ctg (keys %{$pj_hash->{$ctg}->{left}})
                    {
                        #find join to the largest non-scaffold contig
                        next if grep (/^$match_ctg$/, @joined);
                        next if $match_ctg eq $ctg;
                        next if $pj_hash->{$ctg}->{left}->{$match_ctg}->{is_scaffold} eq 'yes';
                        my $overlap = $pj_hash->{$ctg}->{left}->{$match_ctg}->{overlap};
                        next unless $overlap > $longest_overlap;
                        $longest_overlap = $overlap;
                        $hh->{name} = $match_ctg;
                        $hh->{overlap} = $overlap;
                        $hh->{dir} = $pj_hash->{$ctg}->{left}->{$match_ctg}->{dir};
                        $hh->{is_comp} = $pj_hash->{$ctg}->{left}->{$match_ctg}->{is_comp};
                        $hh->{length} = $pj_hash->{$ctg}->{left}->{$match_ctg}->{length};
                    }

                    if ($hh->{name})
                    {
                        push @{$joins->{$ctg}->{left}}, $hh;
                        push @joined, $hh->{name};

                        my $curr_ctg = $hh->{name};
                        my $curr_dir = $hh->{dir};
                        my $continue = 'yes';
                        for (my $i = 0; $i < 50; $i++)
                        {
                            next if $continue eq 'no';
                            my $next_dir = 'right';
                            $next_dir = 'left' if $curr_dir eq 'right';
                            $longest_overlap = 0;
                            my $hhh = {};
                            last unless exists $pj_hash->{$curr_ctg}->{$next_dir};
                            foreach my $next_ctg (keys %{$pj_hash->{$curr_ctg}->{$next_dir}})
                            {
                                next if grep (/^$next_ctg$/, @joined);
                                next if $next_ctg eq $ctg;
                                next if $pj_hash->{$curr_ctg}->{$next_dir}->{$next_ctg}->{is_scaffold} eq 'yes';
                                my $overlap = $pj_hash->{$curr_ctg}->{$next_dir}->{$next_ctg}->{overlap};
                                next unless $overlap > $longest_overlap;
                                $longest_overlap = $overlap;
                                $hhh->{name} = $next_ctg;
                                $hhh->{overlap} = $overlap;
                                $hhh->{dir} = $pj_hash->{$curr_ctg}->{$next_dir}->{$next_ctg}->{dir};
                                $hhh->{is_comp} = $pj_hash->{$curr_ctg}->{$next_dir}->{$next_ctg}->{is_comp};
                                $hhh->{length} = $pj_hash->{$curr_ctg}->{$next_dir}->{$next_ctg}->{length};
                            }

                            unless ($hhh->{name})
                            {
                                $continue = 'no';
                                next;
                            }

                            push @{$joins->{$ctg}->{left}}, $hhh;
                            push @joined, $hhh->{name};

                            $curr_ctg = $hhh->{name};
                            $curr_dir = $hhh->{dir};
                        }
                    }
                }
            }

            #enter loop to find subsequent joins

            #$ctg = Contig1.1
            #$next_scaf_ctg = Contig1.2
            my $prev_scaf_ctg = $next_scaf_ctg;

            #to keep current scaf ctg name in memory
            #this stays true when there are no more than 2 scaffolds;
            my $curr_ctg = $next_scaf_ctg;

            #caution .. this loop is only enterend when there are more than
            #2 sequential scaffold contigs

            #need another name for current contig in the next loop
            my $cur_ctg = $ctg;

            $continue = 'yes';

            for (my $i = 1; $i < 50; $i++)
            {
                next if $continue eq 'no';
                last unless exists $pj_hash->{$next_scaf_ctg};
                last unless exists $pj_hash->{$ctg}->{right};
                my $hh;

                foreach my $next_ctg (keys %{$pj_hash->{$cur_ctg}->{right}})
                {
                    next unless $next_ctg eq $next_scaf_ctg;
                    next if grep (/^$next_ctg$/, @joined);
                    #if the next ctg is less than 500 bp and if is_comp is no then
                    #there's no need to complement the contig even if the matches are
                    if ($pj_hash->{$cur_ctg}->{right}->{$next_ctg}->{length} > 980)
                    {
                        #if contig is less than cross_match length it doesn't matter which
                        #direction match is in
                        last unless $pj_hash->{$cur_ctg}->{right}->{$next_ctg}->{dir} eq 'left';
                        last unless $pj_hash->{$cur_ctg}->{right}->{$next_ctg}->{is_comp} eq 'no';
                    }
                    $hh->{name} = $next_ctg;
                    $hh->{overlap} = $pj_hash->{$cur_ctg}->{right}->{$next_ctg}->{overlap};
                    $hh->{dir} = $pj_hash->{$cur_ctg}->{right}->{$next_ctg}->{dir};
                    $hh->{is_comp} = $pj_hash->{$cur_ctg}->{right}->{$next_ctg}->{is_comp};
                    $hh->{length} = $pj_hash->{$cur_ctg}->{right}->{$next_ctg}->{length};
                }

#		last unless $hh->{name};
                unless ($hh->{name})
                {
                    $continue = 'no';
                    next;
                }

                push @joined, $hh->{name};
                push @{$joins->{$ctg}->{right}}, $hh;
                $cur_ctg = $hh->{name};
                $ctg_num++;
                $next_scaf_ctg = $scaf_name.'.'.$ctg_num;
            }

            #if next scaffold contig exists, ie, if this is not the end of the scaffold
            #go to the next contig and don't extend the right end

#	    next if exists $pj_hash->{$next_scaf_ctg};
            next unless exists $pj_hash->{$ctg}->{is_last_scaf_ctg};

            my $curr_dir = 'defined'; #is right currently
            my $prev_dir = 'defined';

            $continue = 'yes';

            #define last_scaf_ctg and build on the right end
            for (my $i = 0; $i < 50; $i++)
            {
                next if $continue eq 'no';
                $curr_dir = 'right';
                $curr_dir = 'left' if $prev_dir eq 'right';

                my $hh;
                my $longest_overlap = 0;
                last unless exists $pj_hash->{$cur_ctg}->{$curr_dir};
                foreach my $match_ctg (keys %{$pj_hash->{$cur_ctg}->{$curr_dir}})
                {
                    next if grep (/^$match_ctg$/, @joined);
#		    next if $match_ctg eq $ctg;
                    my $overlap = $pj_hash->{$cur_ctg}->{$curr_dir}->{$match_ctg}->{overlap};
                    next unless $overlap > $longest_overlap;
                    $longest_overlap = $overlap;
                    $hh->{name} = $match_ctg;
                    $hh->{overlap} = $overlap;
                    $hh->{dir} = $pj_hash->{$cur_ctg}->{$curr_dir}->{$match_ctg}->{dir};
                    $hh->{is_comp} = $pj_hash->{$cur_ctg}->{$curr_dir}->{$match_ctg}->{is_comp};
                    $hh->{length} = $pj_hash->{$cur_ctg}->{$curr_dir}->{$match_ctg}->{length};
                }
                unless ($hh->{name})
                {
                    $continue = 'no';
                    next;
                }

                push @{$joins->{$ctg}->{right}}, $hh;
                push @joined, $hh->{name};

                $cur_ctg = $hh->{name};
                $prev_dir = $hh->{dir};
            }
        }
    }
    if ($join_small_contigs eq 'yes')
    {
        foreach my $ctg (nsort keys %$pj_hash)
        {
            next if grep (/^$ctg$/, @joined);
            next if $pj_hash->{$ctg}->{is_scaffold} eq 'yes';
            push @joined, $ctg;
            foreach my $dir (sort keys %{$pj_hash->{$ctg}})
            {
                next if $dir eq 'is_scaffold' or $dir eq 'length';
                #left first $dir eq 'left' first then right
                my $current_ctg;
                my $current_dir;
                my $longest_overlap = 0;
                for (my $i = 0; $i < 100; $i++)
                {
                    $current_ctg = $ctg unless $current_ctg;
                    $current_dir = $dir unless $current_dir;

                    #$ctg remains the same through the for loop
                    #but it can be redefined at the bottom of this loop
                    #to be given the $match_ctg value to get the next $match_ctg
                    my $h;
                    foreach my $match_ctg (keys %{$pj_hash->{$current_ctg}->{$current_dir}})
                    {
                        next if grep (/^$match_ctg$/, @joined);

                        my $overlap = $pj_hash->{$current_ctg}->{$current_dir}->{$match_ctg}->{overlap};
                        my $is_comp = $pj_hash->{$current_ctg}->{$current_dir}->{$match_ctg}->{is_comp};
                        my $direction = $pj_hash->{$current_ctg}->{$current_dir}->{$match_ctg}->{dir};

                        #if Left to Left or Right to Right join, is_comp must be 'yes'
                        #if R ot L or L to R join then is_comp must be no
                        #is_comp complemented match from cross_match

                        next if $direction eq $current_dir and $is_comp eq 'no';
                        next if $direction ne $current_dir and $is_comp eq 'yes';

                        next unless $overlap > $longest_overlap;
                        $longest_overlap = $overlap;
                        $h->{name} = $match_ctg;
                        $h->{overlap} = $overlap;
                        $h->{dir} = $pj_hash->{$current_ctg}->{$current_dir}->{$match_ctg}->{dir};
                        $h->{is_comp} = $is_comp;
                        $h->{length} = $pj_hash->{$current_ctg}->{$current_dir}->{$match_ctg}->{length};
                    }
                    last unless $h->{name};
                    push @{$joins->{$ctg}->{$dir}}, $h;
                    push @joined, $h->{name};
                    $current_ctg = $h->{name};
                    $current_dir = 'right';
                    $current_dir = 'left' if $h->{dir} eq 'right';
                }
            }
        }
    }
    return $joins;
}

sub run_cross_match
{
    my ($self, $fasta_file, $ace) = @_;

    my $cm_min_match = 25;
    $cm_min_match = $self->cm_min_match if $self->cm_min_match;

    #need to fix this
    my $cm_out = "$ace".'_aj_cm_out';
    unlink $cm_out if -e $cm_out;

    my $ec = system ("cross_match $fasta_file -minmatch $cm_min_match -masklevel 101 > $cm_out");

    print "cross_match failed .. exiting\n" and exit (1) if $ec;
    return $cm_out;
}

sub parse_cross_match_file
{
    my ($self, $cm_out, $ctg_scaf_hash) = @_;
    my $fh = IO::File->new("<$cm_out");
    my $is_alignment = 0;

    my $joins = {};

    while (my $line = $fh->getline)
    {
        #there's probably a cm parser
        next if $line =~ /^\s+$/;

        if ($line =~ /^Maximal single/)
        {
            $is_alignment = 1;
            next;
        }

        if ($line =~ /^\d+\s+matching\s+entr/)
        {
            $is_alignment = 0;
            next;
        }

        next if $is_alignment == 0;

        chomp $line;
        $line =~ s/^\s+//;

        my @ar = split (/\s+/, $line);

        #complemented matches have C at column 9 so
        #target contig can be in either column 9 or 10
        #source contig is always in column 5

        #$end_1 = subject
        #$end_2 = target

        my $end_1 = $ar[4];
        my $end_2 = ($ar[8] eq 'C') ? $ar[9] : $ar[8];

        #exclude self hits
        next if $end_1 eq $end_2;

        #split up target and subject name to get contig name and end direction
        my ($end_1_ctg_name, $end_1_ctg_dir) = split ('-', $end_1);
        my ($end_2_ctg_name, $end_2_ctg_dir) = split ('-', $end_2);

        #exclude intra ctg hits
        next if $end_1_ctg_name eq $end_2_ctg_name;

        #is complemented
        my $is_comp = ($ar[8] eq 'C') ? 'yes' : 'no';

        #flag subject and target are part of same scaffolds
        my ($end_1_scaf_name, $end_1_scaf_ctg_num) = split (/\./, $end_1_ctg_name);
        my ($end_2_scaf_name, $end_2_scaf_ctg_num) = split (/\./, $end_2_ctg_name);

#	print "$end_1_scaf_name $end_2_scaf_name =====\n";

        my $is_same_scaf = ($end_1_scaf_name eq $end_2_scaf_name) ? 'yes' : 'no';

        #subject is part of scaffold

        my $ctg_1_is_scaf = ( exists $ctg_scaf_hash->{$end_1_ctg_name}->{scaffolds} ) ? 'yes' : 'no';
        my $ctg_2_is_scaf = ( exists $ctg_scaf_hash->{$end_2_ctg_name}->{scaffolds} ) ? 'yes' : 'no';

        #get length of contig

        my $ctg_1_length = $ctg_scaf_hash->{$end_1_ctg_name}->{length};
        my $ctg_2_length = $ctg_scaf_hash->{$end_2_ctg_name}->{length};

        #overlapping bases

        #this is all that is really needed
        my $ctg_1_overlap = $ar[6] - $ar[5];

#	print "$ctg_1_overlap_start $ctg_1_overlap_end $ctg_1_overhang : $ctg_2_overlap_start $ctg_2_overlap_end $ctg_2_overhang\n";

        $joins->{$end_1_ctg_name}->{$end_1_ctg_dir}->{$end_2_ctg_name}->{name}=$end_2_ctg_name;
        $joins->{$end_1_ctg_name}->{$end_1_ctg_dir}->{$end_2_ctg_name}->{dir}=$end_2_ctg_dir;
        $joins->{$end_1_ctg_name}->{$end_1_ctg_dir}->{$end_2_ctg_name}->{is_same_scaf}=$is_same_scaf;
        $joins->{$end_1_ctg_name}->{$end_1_ctg_dir}->{$end_2_ctg_name}->{is_scaffold}=$ctg_2_is_scaf;
        $joins->{$end_1_ctg_name}->{$end_1_ctg_dir}->{$end_2_ctg_name}->{length}=$ctg_2_length;
        $joins->{$end_1_ctg_name}->{$end_1_ctg_dir}->{$end_2_ctg_name}->{overlap} = $ctg_1_overlap;
        $joins->{$end_1_ctg_name}->{$end_1_ctg_dir}->{$end_2_ctg_name}->{is_comp} = $is_comp;
        $joins->{$end_1_ctg_name}->{is_scaffold} = $ctg_1_is_scaf;
        $joins->{$end_1_ctg_name}->{length} = $ctg_1_length if $ctg_1_length;

        if (exists $ctg_scaf_hash->{$end_1_ctg_name}->{scaffolds})
        {
            my $last_scaf_ctg = @{$ctg_scaf_hash->{$end_1_ctg_name}->{scaffolds}}[-1];
            $joins->{$end_1_ctg_name}->{is_last_scaf_ctg} = 'yes' if $last_scaf_ctg eq $end_1_ctg_name;
        }
    }
    $fh->close;

#    print Dumper $joins;

    return $joins;
}


sub print_out_ctg_ends
{
    my ($self, $ace, $ctg_hash) = @_;

    my $min_read_num = 2;
    $min_read_num = $self->min_read_num if $self->min_read_num;

    my $min_length = 100;
    $min_length = $self->min_length if $self->min_length;

    my $max_length = 10000000;
    $max_length = $self->max_length if $self->max_length;

    my $cm_seg = 500;
    $cm_seg = $self->cm_segments if $self->cm_segments;

    my $ace_obj = GSC::IO::Assembly::Ace->new( input_file => $ace, conserve_memory => 1);

    my $contig_names = $ace_obj->get_contig_names;

    my $fasta_file = $ace.'.autojoin_cm_fasta';

    unlink $fasta_file if -e $fasta_file;

    my $fasta_fh = IO::File->new(">>$fasta_file") || die "cannot create $fasta_file file handle";

    foreach my $ctg (@$contig_names)
    {

        $ctg =~ s/^Contig//;

        #exclude those with less than desired read number per ctg
        next if $ctg_hash->{$ctg}->{number_of_reads} < $min_read_num;

#	my $ctg_obj = $ace_obj->get_contig ($ctg);
        my $ctg_obj = $ace_obj->get_contig ('Contig'.$ctg);
        my $seq = $ctg_obj->sequence->unpadded_base_string;

        my $length = length $seq;

        #if ctg is not part of a scaffold and it's length is less than min and more than max
        next if ($length < $min_length and $length > $max_length and ! exists $ctg_hash->{$ctg}->{scaffolds});

        my ($left_seq, $right_seq);

        $cm_seg = $length if $length < $cm_seg;

        ($left_seq) = $seq =~ /^(\w{$cm_seg})/;
        ($right_seq) = $seq =~ /(\w{$cm_seg})$/; 

        $fasta_fh->print (">$ctg"."-left\n"."$left_seq\n");
        $fasta_fh->print (">$ctg"."-right\n"."$right_seq\n");

        $ctg_obj = '';
    }

    $fasta_fh->close;

    $ace_obj = '';

    return $fasta_file;
}

sub get_contigs_info
{
    my $self = shift;
    my $ace = $self->ace;
    my $ctgs = {};
    my $ctgs_list = [];
    my $fh = IO::File->new ("<$ace") || die "Cannot open $ace";
    while (my $line = $fh->getline)
    {
        next unless $line =~ /^CO\s+/;
        my ($ctg_name, $length, $reads_count) = 
        $line =~ /^CO\s+(\S+)\s+(\d+)\s+(\d+)\s+\d+\s+\w$/;

        my ($ctg_num) = $ctg_name =~ /^Contig(\d+\.\d+)$/;

        $ctgs->{$ctg_num}->{name} = $ctg_num;
        $ctgs->{$ctg_num}->{length} = $length;
        $ctgs->{$ctg_num}->{number_of_reads} = $reads_count;

        push @$ctgs_list, $ctg_num
    }
    $fh->close;

    return $ctgs, $ctgs_list;
}

sub gather_scaf_info
{
    my ($self, $h, $ar) = @_;

    foreach my $ctg (nsort keys %$h)
    {
        next unless $ctg =~ /^\d+\.\d+$/;

        my $scaf = $ctg;
        $scaf =~ s/\.\d+$//;

        #pattern match each contig. to find all contigs
        #in each scaffold

        my (@scafs) = grep (/^$scaf\.\d+$/, @$ar);

        #don't hold scaffold contigs if contig
        #is not part of a scaffold

        next unless scalar @scafs > 1;

        @{$h->{$ctg}->{scaffolds}} = @scafs if @scafs;
    }

    return $h;
}


sub fix_ace_qa_line
{
    my $self = shift;
    my $ace = $self->ace;
    print "Invalid file: $ace\n" and return unless -s $ace;
    my $ace_out = $ace.'.QA_line_fixed';
    my $out_fh = IO::File->new(">$ace_out") || die "Cannot write $ace_out";
    my $fh = IO::File->new("<$ace") || die "cannot open $ace";
    my $read_length;
    while (my $line = $fh->getline)
    {
        if ($line =~ /^RD\s+/)
        {
            ($read_length) = $line =~ /^RD\s+\S+\s+(\d+)\s+/;
            $out_fh->print ($line);
        }
        elsif ($line =~ /^QA\s+/)
        {
            my ($start, $end, $align_start, $align_end) = $line =~ /^QA\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)/;
#	    print "read_length: $read_length start: $start end: $end align_start: $align_start align_end: $align_end\n";
            #none of the number must be less than -1
            if ($start < -1 or $end < -1 or $align_start < -1 or $align_end < -1)
            {
                $out_fh->print ("QA -1 -1 -1 -1\n");
                next;
            }
            #none of the number must be greater than $read_length
            elsif ($start > $read_length or $end > $read_length or $align_start > $read_length or $align_end > $read_length)
            {
                $out_fh->print ("QA -1 -1 -1 -1\n");
                next;
            }
            #first two number must not be zero
            elsif ($line =~ /^QA\s+0\s+0/)
            {
                $out_fh->print ("QA -1 -1 -1 -1\n");
                next;
            }
            else
            {
                $out_fh->print ($line);
            }
        }
        else
        {
            $out_fh->print ($line);
        }
    }

    $fh->close;
    $out_fh->close;

    return $ace_out;
}



sub clean_up_tags
{
    my $self = shift;

    my $ace = $self->ace;

    my $fh = IO::File->new("<$ace");
    my $out_fh = IO::File->new(">$ace".'_tags_resolved');
    my @contigs;
    my $tag_setting = 0;
    my $print_tag = 0;
    my $tag_string;
    my $ctg_name_from_tag;
    while (my $line = $fh->getline)
    {
        if ($line =~ /^CO\s+/)
        {
            my ($ctg) = $line =~ /^CO\s+(\S+)\s+/;
            push @contigs, $ctg;
            $out_fh->print ($line);
        }
        elsif ($line =~ /^CT\{/)
        {
            $tag_string .= $line;
            $tag_setting = 1;
        }
        elsif ($tag_setting == 1 and $line =~ /^Contig/)
        {
            ($ctg_name_from_tag) =  $line =~ /^(Contig\S+)\s+/;
            $tag_string .= $line;
            $print_tag = 1;
            next;
        }
        elsif ($tag_setting == 1 and $line =~ /^\}/)
        {
            $tag_string .= $line;
            $tag_setting = 0;
            next;
        }
        elsif ($print_tag == 1)
        {
            $out_fh->print("\n$tag_string\n") if grep (/^$ctg_name_from_tag$/, @contigs);
            $print_tag = 0;
            $tag_string = '';
        }
        else
        {
            $out_fh->print($line);
        }
    }
    $fh->close;
    
#   unlink $ace;

    return $ace.'_tags_resolved';
}

1;
