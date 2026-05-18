/* 1. 원본 불러오기 */
proc import datafile="/home/u64262964/datacontest/w09.csv"
    out=w09
    dbms=csv
    replace;
    getnames=yes;
run;


/* 2. 숫자형으로 변환 */
data w09_num;
    set w09;

    /* 동거 자녀 */
    %macro convert_cohab();
        %do i = 1 %to 9;
            w09Ba013_n&i = input(w09Ba013_0&i, ?? best.);
        %end;
    %mend;
    %convert_cohab

    /* 사회활동 */
    %macro convert_social();
        %do i = 1 %to 7;
            w09A035_n&i = input(w09A035_0&i, ?? best.);
        %end;
    %mend;
    %convert_social

    /* 자녀 만남 */
    %macro convert_meet();
        %do i = 1 %to 9;
            w09Ba019_n&i = input(w09Ba019_0&i, ?? best.);
        %end;
    %mend;
    %convert_meet

    /* 자녀 연락 */
    %macro convert_contact();
        %do i = 1 %to 9;
            w09Ba020_n&i = input(w09Ba020_0&i, ?? best.);
        %end;
    %mend;
    %convert_contact

    /* CES-D10 */
    %macro convert_cesd();
        %do i = 142 %to 151;
            w09C&i._n = input(w09C&i, ?? best.);
        %end;
    %mend;
    %convert_cesd

    /* 우울 여부 */
    w09Cadd_19_n = input(w09Cadd_19, ?? best.);
run;


/* 3. 동거 자녀 및 자녀 없음 제외 + CES-D10 무응답 제거 */
data filtered_data;
    set w09_num;

    array cohab[9] w09Ba013_n1 - w09Ba013_n9;

    has_cohabiting_child = 0;
    has_child = 0;

    do i = 1 to 9;
        if cohab[i] = 1 then has_cohabiting_child = 1;
        if not missing(cohab[i]) then has_child = 1;
    end;

    if has_cohabiting_child = 0 and has_child = 1 and w09Cadd_19 ne 3;
run;

/* 5. CES-D10 점수 계산: 1~4를 0~10로 정규화 */
data filtered_data;
    set filtered_data;

    C142_score = (w09C142_n - 1) / 3;
    C143_score = (w09C143_n - 1) / 3;
    C144_score = (w09C144_n - 1) / 3;
    C145_score = (w09C145_n - 1) / 3;
    C146_score = (4 - w09C146_n) / 3;  /* 역코딩 */
    C147_score = (w09C147_n - 1) / 3;
    C148_score = (w09C148_n - 1) / 3;
    C149_score = (4 - w09C149_n) / 3;  /* 역코딩 */
    C150_score = (w09C150_n - 1) / 3;
    C151_score = (w09C151_n - 1) / 3;

    array scores[*] C142_score C143_score C144_score C145_score C146_score
                     C147_score C148_score C149_score C150_score C151_score;

    valid = 0;
    total = 0;

    do i = 1 to dim(scores);
        if not missing(scores[i]) then do;
            valid + 1;
            total + scores[i];
        end;
    end;

    if valid >= 9 then cesd10_score = (total / valid)*10;
    else cesd10_score = .;
run;

data filtered_data;
    set filtered_data;
    if not missing(cesd10_score);
run;

data filtered_data;
    set filtered_data;

    /* 성별: 1=남, 5=여 → 1=남, 2=여 */
    if input(w09gender1, ?? best.) = 1 then gender = 1;
    else if input(w09gender1, ?? best.) = 5 then gender = 2;

    /* 연령대 그룹화 */
    if w09A002_age >= 65 and w09A002_age <= 69 then age_group = 1;
    else if w09A002_age <= 74 then age_group = 2;
    else if w09A002_age <= 79 then age_group = 3;
    else if w09A002_age <= 84 then age_group = 4;
    else if w09A002_age >= 85 then age_group = 5;

    /* 생존 자녀 수 */
    n_child = input(w09Ba003, ?? best.);

    /* 사회모임 수 계산 */
    array group_vars[7] w09A033m01 - w09A033m07;
    n_social = 0;
    do i = 1 to dim(group_vars);
        if group_vars[i] = 1 then n_social + 1;
    end;
run;

proc freq data=filtered_data;
    tables gender age_group n_child n_social / missing;
run;