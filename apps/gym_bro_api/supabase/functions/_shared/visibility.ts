import { sql } from "npm:kysely@^0.27";

// Who can see a post or a story, as SQL conditions on the `post` / `story`
// alias — shared by the posts and stories functions and by share previews
// in chat (_shared/shares.ts), so every place answers the same way.

/**
 * `post` is visible to the viewer: business posts to everyone; a personal
 * post to its author, and — unless archived or either one blocked the
 * other — to accepted followers, people tagged on it, and everyone when
 * it's 'public' on a public account.
 */
export function postVisibleSql(viewerId: string | null) {
  if (!viewerId) {
    return sql<boolean>`(post.business_id IS NOT NULL OR (post.archived_at IS NULL AND post.visibility = 'public'
      AND NOT (SELECT is_private FROM users WHERE id = post.author_id)))`;
  }
  return sql<boolean>`(
    post.business_id IS NOT NULL
    OR post.author_id = ${viewerId}
    OR (
      post.archived_at IS NULL
      AND NOT is_blocked_between(post.author_id, ${viewerId})
      AND (
        EXISTS (SELECT 1 FROM follow f WHERE f.follower_id = ${viewerId} AND f.followee_id = post.author_id AND f.status = 'accepted')
        OR EXISTS (SELECT 1 FROM post_tag pt WHERE pt.post_id = post.id AND pt.user_id = ${viewerId} AND pt.comment_id IS NULL)
        OR (post.visibility = 'public' AND NOT (SELECT is_private FROM users WHERE id = post.author_id))
      )
    )
  )`;
}

/**
 * `story` is visible to the viewer: always to its author (the archive);
 * to anyone else while it's live, unless either one blocked the other, if
 * they're an accepted follower or the account is public.
 */
export function storyVisibleSql(viewerId: string) {
  return sql<boolean>`(
    story.author_id = ${viewerId}
    OR (
      story.expires_at > NOW()
      AND NOT is_blocked_between(story.author_id, ${viewerId})
      AND (
        EXISTS (SELECT 1 FROM follow f WHERE f.follower_id = ${viewerId} AND f.followee_id = story.author_id AND f.status = 'accepted')
        OR NOT (SELECT is_private FROM users WHERE id = story.author_id)
      )
    )
  )`;
}
