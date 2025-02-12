CREATE FUNCTION
    assessment_groups_add_member(
        assessment_id bigint,
        arg_group_id bigint,
        arg_uid text,
        authn_user_id bigint
    ) RETURNS void
AS $$
DECLARE
    arg_user_id bigint;
    group_config_id bigint;
BEGIN
    -- ##################################################################
    -- verify the updating group belongs to the selected assessment
    -- then lock the group row
    -- TODO: This sproc and associated UI doesn't actually respect maximum size constraints.
    SELECT gc.id
    INTO group_config_id
    FROM
        group_configs AS gc
        JOIN groups AS g ON gc.id = g.group_config_id
    WHERE
        gc.assessment_id = assessment_groups_add_member.assessment_id
        AND g.id = arg_group_id
        AND g.deleted_at IS NULL
    FOR NO KEY UPDATE of g;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'The group does not belong to the assessment';
    END IF;

    -- ##################################################################
    -- get user_id from uid and make sure the user is enrolled in this course instance
    SELECT u.user_id
    INTO arg_user_id
    FROM 
        users AS u
        JOIN enrollments AS e ON e.user_id = u.user_id
        JOIN assessments AS a ON a.course_instance_id = e.course_instance_id AND a.id = assessment_groups_add_member.assessment_id
    WHERE u.uid = arg_uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User does not exist or is not enrolled in this course instance: %', arg_uid;
    END IF;

    -- ##################################################################
    -- ensure the user is not already in another group
    PERFORM 1
    FROM
      group_users AS gu
      JOIN groups AS g ON (g.id = gu.group_id)
      JOIN group_configs AS gc ON (gc.id = g.group_config_id)
    WHERE
      gu.user_id = arg_user_id
      AND gc.assessment_id = assessment_groups_add_member.assessment_id
      AND g.deleted_at IS NULL;

    IF FOUND THEN
        RAISE EXCEPTION 'User is already a member of a group for this assessment';
    END IF;

    -- ##################################################################
    -- insert group_user
    WITH log AS (
        INSERT INTO group_users (group_id, user_id, group_config_id)
        VALUES (arg_group_id, arg_user_id, group_config_id)
        RETURNING group_id
    )
    INSERT INTO group_logs 
        (authn_user_id, user_id, group_id, action)
    SELECT assessment_groups_add_member.authn_user_id, arg_user_id, group_id, 'join'
    FROM log;

END;
$$ LANGUAGE plpgsql VOLATILE;
