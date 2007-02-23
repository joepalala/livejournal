#!/usr/bin/perl
#

use strict;
use lib "$ENV{'LJHOME'}/cgi-bin";

use Class::Autouse qw(
                      LJ::Cache
                      LJ::LangDatFile
                      );

package LJ::Lang;

my @day_short   = (qw[Sun Mon Tue Wed Thu Fri Sat]);
my @day_long    = (qw[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]);
my @month_short = (qw[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec]);
my @month_long  = (qw[January February March April May June July August September October November December]);

# get entire array of days and months
sub day_list_short   { return @LJ::Lang::day_short;   }
sub day_list_long    { return @LJ::Lang::day_long;    }
sub month_list_short { return @LJ::Lang::month_short; }
sub month_list_long  { return @LJ::Lang::month_long;  }

# access individual day or month given integer
sub day_short   { return   $day_short[$_[0] - 1]; }
sub day_long    { return    $day_long[$_[0] - 1]; }
sub month_short { return $month_short[$_[0] - 1]; }
sub month_long  { return  $month_long[$_[0] - 1]; }

# lang codes for individual day or month given integer
sub day_short_langcode   { return "date.day."   . lc(LJ::Lang::day_long(@_))    . ".short"; }
sub day_long_langcode    { return "date.day."   . lc(LJ::Lang::day_long(@_))    . ".long";  }
sub month_short_langcode { return "date.month." . lc(LJ::Lang::month_long(@_))  . ".short"; }
sub month_long_langcode  { return "date.month." . lc(LJ::Lang::month_long(@_))  . ".long";  }

## ordinal suffix
sub day_ord {
    my $day = shift;

    # teens all end in 'th'
    if ($day =~ /1\d$/) { return "th"; }

    # otherwise endings in 1, 2, 3 are special
    if ($day % 10 == 1) { return "st"; }
    if ($day % 10 == 2) { return "nd"; }
    if ($day % 10 == 3) { return "rd"; }

    # everything else (0,4-9) end in "th"
    return "th";
}

sub time_format
{
    my ($hours, $h, $m, $formatstring) = @_;

    if ($formatstring eq "short") {
        if ($hours == 12) {
            my $ret;
            my $ap = "a";
            if ($h == 0) { $ret .= "12"; }
            elsif ($h < 12) { $ret .= ($h+0); }
            elsif ($h == 12) { $ret .= ($h+0); $ap = "p"; }
            else { $ret .= ($h-12); $ap = "p"; }
            $ret .= sprintf(":%02d$ap", $m);
            return $ret;
        } elsif ($hours == 24) {
            return sprintf("%02d:%02d", $h, $m);
        }
    }
    return "";
}

#### ml_ stuff:
my $LS_CACHED = 0;
my %DM_ID = ();     # id -> { type, args, dmid, langs => { => 1, => 0, => 1 } }
my %DM_UNIQ = ();   # "$type/$args" => ^^^
my %LN_ID = ();     # id -> { ..., ..., 'children' => [ $ids, .. ] }
my %LN_CODE = ();   # $code -> ^^^^
my $LAST_ERROR;
my $TXT_CACHE;      # LJ::Cache for text

sub get_cache_object { return $TXT_CACHE; }

sub last_error
{
    return $LAST_ERROR;
}

sub set_error
{
    $LAST_ERROR = $_[0];
    return 0;
}

sub get_lang
{
    my $code = shift;
    load_lang_struct() unless $LS_CACHED;
    return $LN_CODE{$code};
}

sub get_lang_id
{
    my $id = shift;
    load_lang_struct() unless $LS_CACHED;
    return $LN_ID{$id};
}

sub get_dom
{
    my $dmcode = shift;
    load_lang_struct() unless $LS_CACHED;
    return $DM_UNIQ{$dmcode};
}

sub get_dom_id
{
    my $dmid = shift;
    load_lang_struct() unless $LS_CACHED;
    return $DM_ID{$dmid};
}

sub get_domains
{
    load_lang_struct() unless $LS_CACHED;
    return values %DM_ID;
}

sub get_root_lang
{
    my $dom = shift;  # from, say, get_dom
    return undef unless ref $dom eq "HASH";
    foreach (keys %{$dom->{'langs'}}) {
        if ($dom->{'langs'}->{$_}) {
            return get_lang_id($_);
        }
    }
    return undef;
}

sub load_lang_struct
{
    return 1 if $LS_CACHED;
    my $dbr = LJ::get_db_reader();
    return set_error("No database available") unless $dbr;
    my $sth;

    $TXT_CACHE = new LJ::Cache { 'maxbytes' => $LJ::LANG_CACHE_BYTES || 50_000 };

    $sth = $dbr->prepare("SELECT dmid, type, args FROM ml_domains");
    $sth->execute;
    while (my ($dmid, $type, $args) = $sth->fetchrow_array) {
        my $uniq = $args ? "$type/$args" : $type;
        $DM_UNIQ{$uniq} = $DM_ID{$dmid} = {
            'type' => $type, 'args' => $args, 'dmid' => $dmid,
            'uniq' => $uniq,
        };
    }

    $sth = $dbr->prepare("SELECT lnid, lncode, lnname, parenttype, parentlnid FROM ml_langs");
    $sth->execute;
    while (my ($id, $code, $name, $ptype, $pid) = $sth->fetchrow_array) {
        $LN_ID{$id} = $LN_CODE{$code} = {
            'lnid' => $id,
            'lncode' => $code,
            'lnname' => $name,
            'parenttype' => $ptype,
            'parentlnid' => $pid,
        };
    }
    foreach (values %LN_CODE) {
        next unless $_->{'parentlnid'};
        push @{$LN_ID{$_->{'parentlnid'}}->{'children'}}, $_->{'lnid'};
    }

    $sth = $dbr->prepare("SELECT lnid, dmid, dmmaster FROM ml_langdomains");
    $sth->execute;
    while (my ($lnid, $dmid, $dmmaster) = $sth->fetchrow_array) {
        $DM_ID{$dmid}->{'langs'}->{$lnid} = $dmmaster;
    }

    $LS_CACHED = 1;
}

sub langdat_file_of_lang_itcode
{
    my ($lang, $itcode, $want_cvs) = @_;

    my $langdat_file = LJ::Lang::relative_langdat_file_of_lang_itcode($lang, $itcode);
    my $cvs_extra = "";
    if ($want_cvs) {
        if ($lang eq "en") {
            $cvs_extra = "/cvs/livejournal";
        } else {
            $cvs_extra = "/cvs/local";
        }
    }
    return "$ENV{LJHOME}$cvs_extra/$langdat_file";
}

sub relative_langdat_file_of_lang_itcode
{
    my ($lang, $itcode) = @_;

    my $root_lang = "en";
    my $root_lang_local = $LJ::DEFAULT_LANG;

    my $base_file = "bin/upgrading/$lang\.dat";

    # not a root or root_local lang, just return base file location
    unless ($lang eq $root_lang || $lang eq $root_lang_local) {
        return $base_file;
    }

    my $is_local = $lang eq $root_lang_local;

    # is this a filename-based itcode?
    if ($itcode =~ m!^(/.+\.bml)!) {
        my $file = $1;

        # given the filename of this itcode and the current
        # source, what langdat file should we use?
        my $langdat_file = "htdocs$file\.text";
        $langdat_file .= $is_local ? ".local" : "";
        return $langdat_file;
    }

    # not a bml file, goes into base .dat file
    return $base_file;
}

sub itcode_for_langdat_file {
    my ($langdat_file, $itcode) = @_;

    # non-bml itcode, return full itcode path
    unless ($langdat_file =~ m!^/.+\.bml\.text(?:\.local)?$!) {
        return $itcode;
    }

    # bml itcode, strip filename and return
    if ($itcode =~ m!^/.+\.bml(\..+)!) {
        return $1;
    }

    # fallback -- full $itcode
    return $itcode;
}

sub get_chgtime_unix
{
    my ($lncode, $dmid, $itcode) = @_;
    load_lang_struct() unless $LS_CACHED;

    $dmid = int($dmid || 1);

    my $l = get_lang($lncode) or return "No lang info for lang $lncode";
    my $lnid = $l->{'lnid'}
        or die "Could not get lang_id for lang $lncode";

    my $itid = LJ::Lang::get_itemid($dmid, $itcode)
        or return 0;

    my $dbr = LJ::get_db_reader();
    $dmid += 0;
    my $chgtime = $dbr->selectrow_array("SELECT chgtime FROM ml_latest WHERE dmid=? AND itid=? AND lnid=?",
                                        undef, $dmid, $itid, $lnid);
    die $dbr->errstr if $dbr->err;
    return $chgtime ? LJ::mysqldate_to_time($chgtime) : 0;
}

sub get_itemid
{
    &LJ::nodb;
    my ($dmid, $itcode, $opts) = @_;
    load_lang_struct() unless $LS_CACHED;

    my $dbr = LJ::get_db_reader();
    $dmid += 0;
    my $itid = $dbr->selectrow_array("SELECT itid FROM ml_items WHERE dmid=$dmid AND itcode=?", undef, $itcode);
    return $itid if defined $itid;

    my $dbh = LJ::get_db_writer();
    return 0 unless $dbh;

    # allocate a new id
    LJ::get_lock($dbh, 'global', 'mlitem_dmid') || return 0;
    $itid = $dbh->selectrow_array("SELECT MAX(itid)+1 FROM ml_items WHERE dmid=?", undef, $dmid);
    $itid ||= 1; # if the table is empty, NULL+1 == NULL
    $dbh->do("INSERT INTO ml_items (dmid, itid, itcode, notes) ".
             "VALUES (?, ?, ?, ?)", undef, $dmid, $itid, $itcode, $opts->{'notes'});
    LJ::release_lock($dbh, 'global', 'mlitem_dmid');

    if ($dbh->err) {
        return $dbh->selectrow_array("SELECT itid FROM ml_items WHERE dmid=$dmid AND itcode=?",
                                     undef, $itcode);
    }
    return $itid;
}

# this is called when editing text from a web UI.
# first try and run a local hook to save the text,
# if that fails then just call set_text

# returns ($success, $responsemsg) where responsemsg can be output
# from whatever saves the text
sub web_set_text {
    my ($dmid, $lncode, $itcode, $text, $opts) = @_;

    my $resp = '';
    my $hook_ran = 0;

    if (LJ::are_hooks('web_set_text')) {
        $hook_ran = LJ::run_hook('web_set_text', $dmid, $lncode, $itcode, $text, $opts);
    }

    # save in the db
    my $save_success = LJ::Lang::set_text($dmid, $lncode, $itcode, $text, $opts);
    $resp = LJ::Lang::last_error() unless $save_success;
    warn $resp if ! $save_success && $LJ::IS_DEV_SERVER;

    return ($save_success, $resp);
}

sub set_text
{
    &LJ::nodb;
    my ($dmid, $lncode, $itcode, $text, $opts) = @_;
    load_lang_struct() unless $LS_CACHED;

    my $l = $LN_CODE{$lncode} or return set_error("Language not defined.");
    my $lnid = $l->{'lnid'};
    $dmid += 0;

    # is this domain/language request even possible?
    return set_error("Bogus domain")
        unless exists $DM_ID{$dmid};
    return set_error("Bogus lang for that domain")
        unless exists $DM_ID{$dmid}->{'langs'}->{$lnid};

    my $itid = get_itemid($dmid, $itcode, { 'notes' => $opts->{'notes'}});
    return set_error("Couldn't allocate itid.") unless $itid;

    my $dbh = LJ::get_db_writer();
    my $txtid = 0;

    if (defined $text) {
        my $userid = $opts->{'userid'} + 0;
        # Strip bad characters
        $text =~ s/\r//;
        my $qtext = $dbh->quote($text);
        LJ::get_lock( $dbh, 'global', 'ml_text_txtid' ) || return 0;
        $txtid = $dbh->selectrow_array("SELECT MAX(txtid)+1 FROM ml_text WHERE dmid=?", undef, $dmid);
        $txtid ||= 1;
        $dbh->do("INSERT INTO ml_text (dmid, txtid, lnid, itid, text, userid) ".
                 "VALUES ($dmid, $txtid, $lnid, $itid, $qtext, $userid)");
        LJ::release_lock( $dbh, 'global', 'ml_text_txtid' );
        return set_error("Error inserting ml_text: ".$dbh->errstr) if $dbh->err;
    }
    if ($opts->{'txtid'}) {
        $txtid = $opts->{'txtid'}+0;
    }

    my $staleness = $opts->{'staleness'}+0;
    $dbh->do("REPLACE INTO ml_latest (lnid, dmid, itid, txtid, chgtime, staleness) ".
             "VALUES ($lnid, $dmid, $itid, $txtid, NOW(), $staleness)");
    return set_error("Error inserting ml_latest: ".$dbh->errstr) if $dbh->err;
    LJ::MemCache::set("ml.${lncode}.${dmid}.${itcode}", $text) if defined $text;

    {
        my $vals;
        my $langids;
        my $rec = sub {
            my $l = shift;
            my $rec = shift;
            foreach my $cid (@{$l->{'children'}}) {
                my $clid = $LN_ID{$cid};
                if ($opts->{'childrenlatest'}) {
                    my $stale = $clid->{'parenttype'} eq "diff" ? 3 : 0;
                    $vals .= "," if $vals;
                    $vals .= "($cid, $dmid, $itid, $txtid, NOW(), $stale)";
                }
                $langids .= "," if $langids;
                $langids .= $cid+0;
                LJ::MemCache::delete("ml.$clid->{'lncode'}.${dmid}.${itcode}");
                $rec->($clid, $rec);
            }
        };
        $rec->($l, $rec);

        # set descendants to use this mapping
        $dbh->do("INSERT IGNORE INTO ml_latest (lnid, dmid, itid, txtid, chgtime, staleness) ".
                 "VALUES $vals") if $vals;

        # update languages that have no translation yet
        $dbh->do("UPDATE ml_latest SET txtid=$txtid WHERE dmid=$dmid ".
                 "AND lnid IN ($langids) AND itid=$itid AND staleness >= 3") if $langids;
    }

    if ($opts->{'changeseverity'} && $l->{'children'} && @{$l->{'children'}}) {
        my $in = join(",", @{$l->{'children'}});
        my $newstale = $opts->{'changeseverity'} == 2 ? 2 : 1;
        $dbh->do("UPDATE ml_latest SET staleness=$newstale WHERE lnid IN ($in) AND ".
                 "dmid=$dmid AND itid=$itid AND txtid<>$txtid AND staleness < $newstale");
    }

    return 1;
}

sub ml {
    my ($code, $vars) = @_;
    my $lang;

    if (LJ::is_web_context()) {
        # this means we should use BML::ml and not do our own handling
        my $text = BML::ml($code, $vars);
        $LJ::_ML_USED_STRINGS{$code} = $text if $LJ::IS_DEV_SERVER;
        return $text;

    } elsif (my $remote = LJ::get_remote()) {
        # we have a user; try their browse language
        $remote->preload_props("browselang");
        $lang = $remote->{browselang};
    }

    $lang ||= $LJ::DEFAULT_LANG;

    return get_text($lang, $code, undef, $vars);
}

sub string_exists {
    my ($code, $vars) = @_;

    my $string = LJ::Lang::ml($code, $vars);

    return $string !~ /^\[missing string/ && $string !~ /^\[uhhh:/;
}

sub get_text
{
    my ($lang, $code, $dmid, $vars) = @_;

    my $from_db = sub {
        my $text = get_text_multi($lang, $dmid, [ $code ]);
        return $text->{$code};
    };

    my $from_files = sub {
        my ($localcode, @files);
        if ($code =~ m!^(/.+\.bml)(\..+)!) {
            my $file;
            ($file, $localcode) = ("$LJ::HTDOCS$1", $2);
            @files = ("$file.text.local", "$file.text");
        } else {
            $localcode = $code;
            @files = ("$LJ::HOME/bin/upgrading/$LJ::DEFAULT_LANG.dat",
                      "$LJ::HOME/bin/upgrading/en.dat");
        }

        foreach my $tf (@files) {
            next unless -e $tf;

            # compare file modtime to when the string was updated in the DB.
            # whichever is newer is authoritative
            my $fmodtime = (stat $tf)[9];
            my $dbmodtime = LJ::Lang::get_chgtime_unix($lang, $dmid, $code);
            return $from_db->() if ! $fmodtime || $dbmodtime > $fmodtime;

            my $ldf = $LJ::REQ_LANGDATFILE{$tf} ||= LJ::LangDatFile->new($tf);
            my $val = $ldf->value($localcode);
            return $val if $val;
        }
        return "[missing string $code]";
    };

    my $text = ($LJ::IS_DEV_SERVER && ($lang eq "en" ||
                                       $lang eq $LJ::DEFAULT_LANG)) ?
                                       $from_files->() :
                                       $from_db->();

    if ($vars) {
        $text =~ s/\[\[\?([\w\-]+)\|(.+?)\]\]/resolve_plural($lang, $vars, $1, $2)/eg;
        $text =~ s/\[\[([^\[]+?)\]\]/$vars->{$1}/g;
    }

    $LJ::_ML_USED_STRINGS{$code} = $text if $LJ::IS_DEV_SERVER;

    return $text || ($LJ::IS_DEV_SERVER ? "[uhhh: $code]" : "");
}

# Loads multiple language strings at once.  These strings
# cannot however contain variables, if you have variables
# you wouldn't be calling this anyway!
# args: $lang, $dmid, array ref of lang codes
sub get_text_multi
{
    my ($lang, $dmid, $codes) = @_;

    return {} unless $codes;

    $dmid = int($dmid || 1);
    $lang ||= $LJ::DEFAULT_LANG;
    load_lang_struct() unless $LS_CACHED;
    my %strings;
    my @memkeys;
    my @dbload;
    my $c = 0;

    foreach my $code (@$codes) {
        my $cache_key = "ml.${lang}.${dmid}.${code}";
        my $text = $TXT_CACHE->get($cache_key);

        if ($text) {
            $strings{$code} = $text;
            $LJ::_ML_USED_STRINGS{$code} = $text if $LJ::IS_DEV_SERVER;
            delete @$codes[$c];
        } else {
            push @memkeys, $cache_key;
        }
        $c++;
    }

    return \%strings unless @memkeys;

    my $mem = LJ::MemCache::get_multi(@memkeys) || {};

    foreach my $code (@$codes) {
        next unless $code;

        my $cache_key = "ml.${lang}.${dmid}.${code}";
        my $text = $mem->{$cache_key};

        if ($text) {
            $strings{$code} = $text;
            $LJ::_ML_USED_STRINGS{$code} = $text if $LJ::IS_DEV_SERVER;
            $TXT_CACHE->set($cache_key, $text);
        } else {
            push @dbload, $code;
        }
    }

    return \%strings unless @dbload;

    my $l = $LN_CODE{$lang};

    # This shouldn't happen!
    die ("Unable to load language code") unless $l;

    my $dbr = LJ::get_db_reader();
    my $bind = join(',', map { '?' } @dbload);
    my $sth = $dbr->prepare("SELECT i.itcode, t.text".
                            " FROM ml_text t, ml_latest l, ml_items i".
                            " WHERE t.dmid=? AND t.txtid=l.txtid".
                            " AND l.dmid=? AND l.lnid=? AND l.itid=i.itid".
                            " AND i.dmid=? AND i.itcode IN ($bind)");
    $sth->execute($dmid, $dmid, $l->{lnid}, $dmid, @dbload);

    while (my ($code, $text) = $sth->fetchrow_array) {
        $strings{$code} = $text;
        $LJ::_ML_USED_STRINGS{$code} = $text if $LJ::IS_DEV_SERVER;

        my $cache_key = "ml.${lang}.${dmid}.${code}";
        $TXT_CACHE->set($cache_key, $text);
        LJ::MemCache::set($cache_key, $text);
    }

    return \%strings;
}

sub get_lang_names {
    my @langs = @_;
    push @langs, @LJ::LANGS unless @langs;

    my @list;

    foreach my $code (@langs) {
        my $l = LJ::Lang::get_lang($code);
        next unless $l;

        my $item = "langname.$code";
        my $namethislang = BML::ml($item);
        my $namenative = LJ::Lang::get_text($l->{'lncode'}, $item);

        push @list, $code, $namenative;
    }

    return \@list;
}

# The translation system now supports the ability to add multiple plural forms of the word
# given different rules in a languge.  This functionality is much like the plural support
# in the S2 styles code.  To use this code you must use the BML::ml function and pass
# the number of items as one of the variables.  To make sure that you are allowing the
# utmost compatibility for each language you should not hardcode the placement of the
# number of items in relation to the noun.  Let the translation string do this for you.
# A translation string is in the format of, with num being the variable storing the
# number of items.
# =[[num]] [[?num|singular|plural1|plural2|pluralx]]

sub resolve_plural {
    my ($lang, $vars, $varname, $wordlist) = @_;
    my $count = $vars->{$varname};
    my @wlist = split(/\|/, $wordlist);
    my $plural_form = plural_form($lang, $count);
    return $wlist[$plural_form];
}

# TODO: make this faster, using AUTOLOAD and symbol tables pointing to dynamically
# generated subs which only use $_[0] for $count.
sub plural_form {
    my ($lang, $count) = @_;
    return plural_form_en($count) if $lang =~ /^en/;
    return plural_form_ru($count) if $lang =~ /^ru/ || $lang =~ /^uk/ || $lang =~ /^be/;
    return plural_form_fr($count) if $lang =~ /^fr/ || $lang =~ /^pt_BR/;
    return plural_form_lt($count) if $lang =~ /^lt/;
    return plural_form_pl($count) if $lang =~ /^pl/;
    return plural_form_singular() if $lang =~ /^hu/ || $lang =~ /^ja/ || $lang =~ /^tr/;
    return plural_form_lv($count) if $lang =~ /^lv/;
    return plural_form_is($count) if $lang =~ /^is/;
    return plural_form_en($count);  # default
}

# English, Danish, German, Norwegian, Swedish, Estonian, Finnish, Greek, Hebrew, Italian, Portugese, Spanish, Esperanto
sub plural_form_en {
    my ($count) = shift;
    return 0 if $count == 1;
    return 1;
}

# French, Brazilian Portuguese
sub plural_form_fr {
    my ($count) = shift;
    return 1 if $count > 1;
    return 0;
}

# Croatian, Czech, Russian, Slovak, Ukrainian, Belarusian
sub plural_form_ru {
    my ($count) = shift;
    return 0 if ($count%10 == 1 and $count%100 != 11);
    return 1 if ($count%10 >= 2 and $count%10 <= 4 and ($count%100 < 10 or $count%100>=20));
    return 2;
}

# Polish
sub plural_form_pl {
    my ($count) = shift;
    return 0 if($count == 1);
    return 1 if($count%10 >= 2 && $count%10 <= 4 && ($count%100 < 10 || $count%100 >= 20));
    return 2;
}

# Lithuanian
sub plural_form_lt {
    my ($count) = shift;
    return 0 if($count%10 == 1 && $count%100 != 11);
    return 1 if ($count%10 >= 2 && ($count%100 < 10 || $count%100 >= 20));
    return 2;
}

# Hungarian, Japanese, Korean (not supported), Turkish
sub plural_form_singular {
    return 0;
}

# Latvian
sub plural_form_lv {
    my ($count) = shift;
    return 0 if($count%10 == 1 && $count%100 != 11);
    return 1 if($count != 0);
    return 2;
}

# Icelandic
sub plural_form_is {
    my ($count) = shift;
    return 0 if ($count%10 == 1 and $count%100 != 11);
    return 1;
}

1;
