<script>
import { GlAvatarLink, GlAvatar } from '@gitlab/ui';
import { ASC } from '~/notes/constants';
import TimelineEntryItem from '~/vue_shared/components/notes/timeline_entry_item.vue';
import DiscussionNotesRepliesWrapper from '~/notes/components/discussion_notes_replies_wrapper.vue';
import ToggleRepliesWidget from '~/notes/components/toggle_replies_widget.vue';
import WorkItemNote from '~/work_items/components/notes/work_item_note.vue';
import WorkItemNoteReplying from '~/work_items/components/notes/work_item_note_replying.vue';
import WorkItemAddNote from './work_item_add_note.vue';

export default {
  components: {
    TimelineEntryItem,
    GlAvatarLink,
    GlAvatar,
    WorkItemNote,
    WorkItemAddNote,
    ToggleRepliesWidget,
    DiscussionNotesRepliesWrapper,
    WorkItemNoteReplying,
  },
  props: {
    workItemId: {
      type: String,
      required: true,
    },
    queryVariables: {
      type: Object,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
    workItemType: {
      type: String,
      required: true,
    },
    fetchByIid: {
      type: Boolean,
      required: false,
      default: false,
    },
    discussion: {
      type: Array,
      required: true,
    },
    sortOrder: {
      type: String,
      default: ASC,
      required: false,
    },
  },
  data() {
    return {
      isExpanded: true,
      autofocus: false,
      isReplying: false,
      replyingText: '',
      showForm: false,
    };
  },
  computed: {
    note() {
      return this.discussion[0];
    },
    author() {
      return this.note.author;
    },
    noteAnchorId() {
      return `note_${this.note.id}`;
    },
    hasReplies() {
      return Boolean(this.replies?.length);
    },
    replies() {
      if (this.discussion?.length > 1) {
        return this.discussion.slice(1);
      }
      return null;
    },
    discussionId() {
      return this.discussion[0]?.discussion?.id || '';
    },
    shouldShowReplyForm() {
      return this.showForm || this.hasReplies;
    },
  },
  methods: {
    showReplyForm() {
      this.showForm = true;
      this.isExpanded = true;
      this.autofocus = true;
    },
    hideReplyForm() {
      this.isExpanded = this.hasReplies;
      this.autofocus = false;
    },
    toggleDiscussion() {
      this.isExpanded = !this.isExpanded;
    },
    threadKey(note) {
      /* eslint-disable @gitlab/require-i18n-strings */
      return `${note.id}-thread`;
    },
    onReplied() {
      this.isExpanded = true;
      this.isReplying = false;
      this.replyingText = '';
    },
    onReplying(commentText) {
      this.isReplying = true;
      this.replyingText = commentText;
    },
  },
};
</script>

<template>
  <timeline-entry-item
    :id="noteAnchorId"
    :class="{ 'internal-note': note.internal }"
    :data-note-id="note.id"
    class="note note-wrapper note-comment gl-px-0"
  >
    <div class="timeline-avatar gl-float-left">
      <gl-avatar-link :href="author.webUrl">
        <gl-avatar
          :src="author.avatarUrl"
          :entity-name="author.username"
          :alt="author.name"
          :size="32"
        />
      </gl-avatar-link>
    </div>

    <div class="timeline-content">
      <div class="discussion-body">
        <div class="discussion-wrapper">
          <div class="discussion-notes">
            <ul class="notes">
              <work-item-note
                :is-first-note="true"
                :note="note"
                :discussion-id="discussionId"
                :has-replies="hasReplies"
                :work-item-type="workItemType"
                :class="{ 'gl-mb-4': hasReplies }"
                @startReplying="showReplyForm"
                @deleteNote="$emit('deleteNote', note)"
                @error="$emit('error', $event)"
              />
              <discussion-notes-replies-wrapper>
                <toggle-replies-widget
                  v-if="hasReplies"
                  :collapsed="!isExpanded"
                  :replies="replies"
                  @toggle="toggleDiscussion({ discussionId })"
                />
                <template v-if="isExpanded">
                  <template v-for="reply in replies">
                    <work-item-note
                      :key="threadKey(reply)"
                      :discussion-id="discussionId"
                      :note="reply"
                      :work-item-type="workItemType"
                      @startReplying="showReplyForm"
                      @deleteNote="$emit('deleteNote', reply)"
                      @error="$emit('error', $event)"
                    />
                  </template>
                  <work-item-note-replying v-if="isReplying" :body="replyingText" />
                  <work-item-add-note
                    v-if="shouldShowReplyForm"
                    :autofocus="autofocus"
                    :query-variables="queryVariables"
                    :full-path="fullPath"
                    :work-item-id="workItemId"
                    :fetch-by-iid="fetchByIid"
                    :discussion-id="discussionId"
                    :work-item-type="workItemType"
                    :sort-order="sortOrder"
                    :add-padding="true"
                    @cancelEditing="hideReplyForm"
                    @replied="onReplied"
                    @replying="onReplying"
                    @error="$emit('error', $event)"
                  />
                </template>
              </discussion-notes-replies-wrapper>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </timeline-entry-item>
</template>
