package Genome::Model::Tools::Assembly::Repair::AutoJoin::ByScaffolding;

use strict;
use warnings;
use Genome;

use Data::Dumper;
use Cwd;

use Finishing::Assembly::Factory;
use Finishing::Assembly::ContigTools;

use Sort::Naturally;

class Genome::Model::Tools::Assembly::Repair::AutoJoin::ByScaffolding
{
    is => ['Genome::Model::Tools::Assembly::Repair::AutoJoin'],
    has => [
	    ace => {
		type => 'String',
		is_optional => 0,
		doc => "input ace file name"        
		},
	    dir => {
		type => 'String',
		is_optional => 1,
		doc => "path to data if specified otherwise cwd"
		},
	    min_length => {
		type => 'String',
		is_optional => 1,
		doc => "minimum match length"        
		}, 
	    max_length => {
		type => 'String',
		is_optional => 1,
		doc => "maximum crossmatch length"        
		},
	    min_read_num => {
		type => 'String',
		is_optional => 1,
		doc => "minimum number of reads to support joins"        
		},
	    cm_fasta_length => {
		type => 'String',
		is_optional => 1,
		doc => "Length of sequences at each ends to run cross match"        
		},
	    cm_min_match => {
		type => 'String',
		is_optional => 1,
		doc => "Minimum length of cross match to consider for join"        
		},
	    ],
};

sub help_brief {
    'Align contigs only by scaffolding'
}

sub help_detail {
    return <<"EOS"
	Align contigs only by scaffolding
EOS
}

sub execute {
    my ($self) = @_;

    #RESOLVE PATH TO DATA
    if ($self->dir)
    {
	my $dir = $self->dir;
	$self->error_message("Path must be edit_dir") and return
	    unless $dir =~ /edit_dir$/;
	$self->error_message("Invalid dir path: $dir") and return
	    unless -d $dir;
	chdir ("$dir");
    }
    else
    {
	my $dir = cwd();
	$self->error_message("You must be in edit_dir") and return
	    unless $dir =~ /edit_dir$/;
    }

    #ACE FILE
    my $ace_in = $self->ace;

    #CHECK TO MAKE SURE ACE FILE EXISTS
    unless (-s $ace_in)
    {
	$self->error_message("Invalid ace file: $ace_in");
	return;
    }

    #CAT ALL PHDBALL FILES TOGETHER IF PRESENT SINCE PHDBALL FACTORY ONLY
    #WORK WITH SINGLE PHDBALL FILE
    #TODO - FIX THIS IN PHDBALL FACTORY
    unless ($self->cat_all_phdball_files)
    {
	$self->error_message("Cound not resolve phdball issues");
	return;
    }

    #DS LINE IN 454 ACE FILES HAS TO HAVE PHD_FILE: TRACE_NAME TO WORK W CONTIGTOOLS
    #THIS CREATES A NEW ACE FILE: $ace_in.DS_Line_fixed;
    #TODO - FIX THIS IN CONTIG TOOLS
    my $new_ace;
    unless ($new_ace = $self->add_phd_to_ace_DS_line ($ace_in))
    {
	$self->error_message("Cound not add PHD_FILE: READ_NAME to ace DS line");
	return;
    }

    #LOAD ACE OBJECT
    my ($ace_obj, $contig_tool);
    unless (($ace_obj, $contig_tool) = $self->_load_ace_obj ($new_ace))
    {
	$self->error_message("Unable to load ace object");
	return;
    }

    #GET GENERAL CONTIG INFO
    my $scaffolds;
    unless ($scaffolds = $self->get_contigs_info_from_ace ($ace_obj))
    {
	$self->error_message("Could not get contig info from ace");
	return;
    }

    #PRINT CONTIG END SEQUENCES TO RUN CROSS MATCH
    unless ($self->_print_contig_ends ($ace_obj, $scaffolds))
    {
	$self->error_message("Could not print contig ends for cross_match");
	return;
    } 

    #RUN CROSS MATCH
    unless ($self->_run_cross_match)
    {
	$self->error_message("Could not run cross_match");
	return;
    }

    #PARSE CROSS MATCH OUTPUT FILE TO FIND JOINS
    my $pre_joins;
    unless ($pre_joins = $self->_parse_cross_match_file ($scaffolds))
    {
	$self->error_message("Failed to parse cross match out file");
	return;
    }

    #FIND JOINS
    my $joins;
    unless ($joins = $self->_find_joins ($pre_joins))
    {
	$self->error_message("Find joins failed");
	return;
    }

    #ALIGN JOINS
    my $aligned_joins;
    unless ($aligned_joins = $self->_align_joins ($joins))
    {
	$self->error_message("Align joins failed");
	return;
    }

    #MAKE JOINS
    my $merged_ace;
    unless ($merged_ace = $self->_make_joins($aligned_joins, $ace_obj, $contig_tool))
    {
	$self->error_message("Make joins failed");
	return;
    }

    #CLEAN UP
    unless ($self->clean_up_merged_ace ($merged_ace))
    {
	$self->error_message("Unable to clean up merged ace file");
	return;
    }

    return 1;
}


sub _run_cross_match
{
    my ($self) = @_;

    my $min_match = 25;

    $min_match = $self->cm_min_match if $self->cm_min_match;
    
    return unless ($self->run_cross_match ($min_match));

    return 1;
}

sub _load_ace_obj
{
    my ($self, $ace) = @_;

    my $tool = Finishing::Assembly::ContigTools->new;

    my $fo = Finishing::Assembly::Factory->connect('ace', $ace);

    return $fo->get_assembly, $tool;
}

sub _print_contig_ends
{
    my ($self, $ao, $scaf_contigs) = @_;

    my $length = 500;

    $length = $self->cm_fasta_length if $self->cm_fasta_length;

    unless ($self->print_contig_ends ($ao, $scaf_contigs, $length))
    {
	$self->error_message("Failed to print contig ends for cross_match");
	return;
    }

    return 1;
}

sub _align_joins
{
    my ($self, $h) = @_;

    my @new_scafs;
    foreach my $scaf (nsort keys %$h)
    {
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
#                print ($contig.$overlap);
                $txt .= $contig.$overlap;
                $i++;
            }
        }
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
#                print ($overlap.$contig);
                $txt .= $overlap.$contig;
            }
        }
        push @new_scafs, $txt;
    }
    return \@new_scafs;
}

sub _parse_cross_match_file
{
    my ($self, $ctg_scaf_hash) = @_;

    my $fh = IO::File->new("< AutoJoin_CM_fasta_out");
    my $is_alignment = 0;

    my $joins = {};

    while (my $line = $fh->getline)
    {
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
	
	$end_1_ctg_name =~ s/contig//i;
	$end_2_ctg_name =~ s/contig//i;

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

    return $joins;
}
sub _find_joins
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

sub _make_joins
{
    my ($self, $scafs, $ace_obj, $ctg_tool) = @_;

    my $dir = cwd();

    print "Please wait: gathering phds and ace file .. this could take up to 10 minutes\n";

    my $ace_out = $self->ace.'.autojoined';

    my $xport = Finishing::Assembly::Ace::Exporter->new( file => $ace_out );

    my @phd_objs;

    my $phd_dir = "$dir/../phd_dir";

    if (-d $phd_dir)
    {
	my $phd_obj = Finishing::Assembly::Phd->new(input_directory => "$phd_dir");

	unless ($phd_obj)
	{
	    $self->error_message("Unable to create phd_dir object");
	    return;
	}

	push @phd_objs, $phd_obj;
    }

    my $phd_ball = "$dir/../phdball_dir/autoJoinPhdBall";

    if (-s $phd_ball)
    {
        my $phd_ball_obj = Finishing::Assembly::Phd::Ball->connect(ball => $phd_ball);

	unless ($phd_ball_obj)
	{
	    $self->error_message("Unable to create phdball object");
	    return;
	}

        push @phd_objs, $phd_ball_obj;
    }

    unless (scalar @phd_objs > 0)
    {
	$self->error_message("No phd objects were loaded");
	return;
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

        $line =~ s/^New\s+scaffold:\s+(\d+\.\d+)\s+//; #GET RID OF THIS
        my @ctgs = split (/\s+\<-\d+-\>\s+/, $line);

        my $next_ctg = shift @ctgs;

        #accepts (1.1) or 1.1 and returns the following
        #Contig1.1, yes for (1.1) and
        #Contig1.1, no for 1.1

        my ($left_ctg_name, $left_comp) = $self->_resolve_complementation ($next_ctg);

        my $left_ctg_obj;

	unless ($left_ctg_obj = $ace_obj->get_contig ($left_ctg_name))
	{
	    $self->error_message("Unable to get contig object for $left_ctg_name");
	    return;
	}

	if ($left_comp eq 'yes')
	{
	    unless ($left_ctg_obj->complement)
	    {
		$self->error_message("Unable to complement contig: $left_ctg_name");
		return;
	    }
	}

        while (scalar @ctgs > 0)
        {
            $next_ctg = shift @ctgs;
            my ($right_ctg_name, $right_comp) = $self->_resolve_complementation ($next_ctg);

            my $right_ctg_obj;

	    unless ($right_ctg_obj = $ace_obj->get_contig($right_ctg_name))
	    {
		$self->error_message("Unable to get contig_obj: $right_ctg_name");
		return;
	    }

	    if ($right_comp eq 'yes')
	    {
		unless ($right_ctg_obj->complement)
		{
		    $self->error_message("Unable to complement contig: $right_ctg_name");
		    return;
		}
	    }

            eval {
                $left_ctg_obj = $ctg_tool->merge($left_ctg_obj, $right_ctg_obj, undef, phd_array => \@phd_objs);
            };

            if ($@)
            {
		#MERGE FAILED SO EXPORT THE LEFT CONTIG
		$xport->export_contig(contig => $left_ctg_obj);

		#REMOVE IT FROM LIST OF CONTIGS THAT WILL LATER ALL BE EXPORTED
		delete $unused_contig_names{$left_ctg_name} if exists $unused_contig_names{$left_ctg_name};

		#IF RIGHT CONTIG WAS THE LAST CONTIG IN SCAFFOLD JUST EXPORT THAT TOO
		if (scalar @ctgs == 0)
		{
		    $xport->export_contig(contig => $right_ctg_obj);
		    delete $unused_contig_names{$right_ctg_name} if exists $unused_contig_names{$right_ctg_name};
		    next;
		}

		#MAKE THE RIGHT CONTIG OBJECT THE LEFT CONTIG OBJECT
		$right_ctg_obj = $left_ctg_obj;

		#CONTINUE TO MERGE USING RIGHT CONTIG AS THE NEXT LEFT CONTIG
		next;
            }

	    #TODO CREATE LOG FILE THAT LISTS ALL THE JOINS

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

    #TURN THIS BACK ON LATER
#   unlink $phd_ball if -s $phd_ball;

    return $ace_out;
}

sub _resolve_complementation
{
    my ($self, $contig_number) = @_;
    return 'Contig'.$contig_number, 'no' unless $contig_number =~ /\(\S+\)/;
    ($contig_number) = $contig_number =~ /\((\S+)\)/;
    return 'Contig'.$contig_number, 'yes';
}

1;
