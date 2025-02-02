import { GlSkeletonLoader, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import SystemNote from '~/work_items/components/notes/system_note.vue';
import WorkItemNotes from '~/work_items/components/work_item_notes.vue';
import WorkItemDiscussion from '~/work_items/components/notes/work_item_discussion.vue';
import WorkItemAddNote from '~/work_items/components/notes/work_item_add_note.vue';
import WorkItemNotesActivityHeader from '~/work_items/components/notes/work_item_notes_activity_header.vue';
import workItemNotesQuery from '~/work_items/graphql/notes/work_item_notes.query.graphql';
import workItemNotesByIidQuery from '~/work_items/graphql/notes/work_item_notes_by_iid.query.graphql';
import deleteWorkItemNoteMutation from '~/work_items/graphql/notes/delete_work_item_notes.mutation.graphql';
import workItemNoteCreatedSubscription from '~/work_items/graphql/notes/work_item_note_created.subscription.graphql';
import workItemNoteUpdatedSubscription from '~/work_items/graphql/notes/work_item_note_updated.subscription.graphql';
import workItemNoteDeletedSubscription from '~/work_items/graphql/notes/work_item_note_deleted.subscription.graphql';
import { DEFAULT_PAGE_SIZE_NOTES, WIDGET_TYPE_NOTES } from '~/work_items/constants';
import { ASC, DESC } from '~/notes/constants';
import {
  mockWorkItemNotesResponse,
  workItemQueryResponse,
  mockWorkItemNotesByIidResponse,
  mockMoreWorkItemNotesResponse,
  mockWorkItemNotesResponseWithComments,
  workItemNotesCreateSubscriptionResponse,
  workItemNotesUpdateSubscriptionResponse,
  workItemNotesDeleteSubscriptionResponse,
} from '../mock_data';

const mockWorkItemId = workItemQueryResponse.data.workItem.id;
const mockNotesWidgetResponse = mockWorkItemNotesResponse.data.workItem.widgets.find(
  (widget) => widget.type === WIDGET_TYPE_NOTES,
);

const mockNotesByIidWidgetResponse = mockWorkItemNotesByIidResponse.data.workspace.workItems.nodes[0].widgets.find(
  (widget) => widget.type === WIDGET_TYPE_NOTES,
);

const mockMoreNotesWidgetResponse = mockMoreWorkItemNotesResponse.data.workItem.widgets.find(
  (widget) => widget.type === WIDGET_TYPE_NOTES,
);

const mockWorkItemNotesWidgetResponseWithComments = mockWorkItemNotesResponseWithComments.data.workItem.widgets.find(
  (widget) => widget.type === WIDGET_TYPE_NOTES,
);

const firstSystemNodeId = mockNotesWidgetResponse.discussions.nodes[0].notes.nodes[0].id;

const mockDiscussions = mockWorkItemNotesWidgetResponseWithComments.discussions.nodes;

describe('WorkItemNotes component', () => {
  let wrapper;

  Vue.use(VueApollo);

  const showModal = jest.fn();

  const findAllSystemNotes = () => wrapper.findAllComponents(SystemNote);
  const findAllListItems = () => wrapper.findAll('ul.timeline > *');
  const findWorkItemAddNote = () => wrapper.findComponent(WorkItemAddNote);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findActivityHeader = () => wrapper.findComponent(WorkItemNotesActivityHeader);
  const findSystemNoteAtIndex = (index) => findAllSystemNotes().at(index);
  const findAllWorkItemCommentNotes = () => wrapper.findAllComponents(WorkItemDiscussion);
  const findWorkItemCommentNoteAtIndex = (index) => findAllWorkItemCommentNotes().at(index);
  const findDeleteNoteModal = () => wrapper.findComponent(GlModal);

  const workItemNotesQueryHandler = jest.fn().mockResolvedValue(mockWorkItemNotesResponse);
  const workItemNotesByIidQueryHandler = jest
    .fn()
    .mockResolvedValue(mockWorkItemNotesByIidResponse);
  const workItemMoreNotesQueryHandler = jest.fn().mockResolvedValue(mockMoreWorkItemNotesResponse);
  const workItemNotesWithCommentsQueryHandler = jest
    .fn()
    .mockResolvedValue(mockWorkItemNotesResponseWithComments);
  const deleteWorkItemNoteMutationSuccessHandler = jest.fn().mockResolvedValue({
    data: { destroyNote: { note: null, __typename: 'DestroyNote' } },
  });
  const notesCreateSubscriptionHandler = jest
    .fn()
    .mockResolvedValue(workItemNotesCreateSubscriptionResponse);
  const notesUpdateSubscriptionHandler = jest
    .fn()
    .mockResolvedValue(workItemNotesUpdateSubscriptionResponse);
  const notesDeleteSubscriptionHandler = jest
    .fn()
    .mockResolvedValue(workItemNotesDeleteSubscriptionResponse);
  const errorHandler = jest.fn().mockRejectedValue('Houston, we have a problem');

  const createComponent = ({
    workItemId = mockWorkItemId,
    fetchByIid = false,
    defaultWorkItemNotesQueryHandler = workItemNotesQueryHandler,
    deleteWINoteMutationHandler = deleteWorkItemNoteMutationSuccessHandler,
  } = {}) => {
    wrapper = shallowMount(WorkItemNotes, {
      apolloProvider: createMockApollo([
        [workItemNotesQuery, defaultWorkItemNotesQueryHandler],
        [workItemNotesByIidQuery, workItemNotesByIidQueryHandler],
        [deleteWorkItemNoteMutation, deleteWINoteMutationHandler],
        [workItemNoteCreatedSubscription, notesCreateSubscriptionHandler],
        [workItemNoteUpdatedSubscription, notesUpdateSubscriptionHandler],
        [workItemNoteDeletedSubscription, notesDeleteSubscriptionHandler],
      ]),
      propsData: {
        workItemId,
        queryVariables: {
          id: workItemId,
        },
        fullPath: 'test-path',
        fetchByIid,
        workItemType: 'task',
      },
      stubs: {
        GlModal: stubComponent(GlModal, { methods: { show: showModal } }),
      },
    });
  };

  beforeEach(async () => {
    createComponent();
  });

  it('has the work item note activity header', () => {
    expect(findActivityHeader().exists()).toBe(true);
  });

  it('passes correct props to comment form component', async () => {
    createComponent({
      workItemId: mockWorkItemId,
      fetchByIid: false,
      defaultWorkItemNotesQueryHandler: workItemNotesByIidQueryHandler,
    });
    await waitForPromises();

    expect(findWorkItemAddNote().props('fetchByIid')).toEqual(false);
  });

  describe('when notes are loading', () => {
    it('renders skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('does not render system notes', () => {
      expect(findAllSystemNotes().exists()).toBe(false);
    });
  });

  describe('when notes have been loaded', () => {
    it('does not render skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('renders system notes to the length of the response', async () => {
      await waitForPromises();
      expect(findAllSystemNotes()).toHaveLength(mockNotesWidgetResponse.discussions.nodes.length);
    });
  });

  describe('when the notes are fetched by `iid`', () => {
    beforeEach(async () => {
      createComponent({ workItemId: mockWorkItemId, fetchByIid: true });
      await waitForPromises();
    });

    it('renders the notes list to the length of the response', () => {
      expect(workItemNotesByIidQueryHandler).toHaveBeenCalled();
      expect(findAllSystemNotes()).toHaveLength(
        mockNotesByIidWidgetResponse.discussions.nodes.length,
      );
    });

    it('passes correct props to comment form component', () => {
      expect(findWorkItemAddNote().props('fetchByIid')).toEqual(true);
    });
  });

  describe('Pagination', () => {
    describe('When there is no next page', () => {
      it('fetch more notes is not called', async () => {
        createComponent();
        await nextTick();
        expect(workItemMoreNotesQueryHandler).not.toHaveBeenCalled();
      });
    });

    describe('when there is next page', () => {
      beforeEach(async () => {
        createComponent({ defaultWorkItemNotesQueryHandler: workItemMoreNotesQueryHandler });
        await waitForPromises();
      });

      it('fetch more notes should be called', async () => {
        expect(workItemMoreNotesQueryHandler).toHaveBeenCalledWith({
          pageSize: DEFAULT_PAGE_SIZE_NOTES,
          id: 'gid://gitlab/WorkItem/1',
        });

        await nextTick();

        expect(workItemMoreNotesQueryHandler).toHaveBeenCalledWith({
          pageSize: 45,
          id: 'gid://gitlab/WorkItem/1',
          after: mockMoreNotesWidgetResponse.discussions.pageInfo.endCursor,
        });
      });
    });
  });

  describe('Sorting', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('sorts the list when the `changeSort` event is emitted', async () => {
      expect(findSystemNoteAtIndex(0).props('note').id).toEqual(firstSystemNodeId);

      await findActivityHeader().vm.$emit('changeSort', DESC);

      expect(findSystemNoteAtIndex(0).props('note').id).not.toEqual(firstSystemNodeId);
    });

    it('puts form at start of list in when sorting by newest first', async () => {
      await findActivityHeader().vm.$emit('changeSort', DESC);

      expect(findAllListItems().at(0).is(WorkItemAddNote)).toEqual(true);
    });

    it('puts form at end of list in when sorting by oldest first', async () => {
      await findActivityHeader().vm.$emit('changeSort', ASC);

      expect(findAllListItems().at(-1).is(WorkItemAddNote)).toEqual(true);
    });
  });

  describe('Activity comments', () => {
    beforeEach(async () => {
      createComponent({
        defaultWorkItemNotesQueryHandler: workItemNotesWithCommentsQueryHandler,
      });
      await waitForPromises();
    });

    it('should not have any system notes', () => {
      expect(workItemNotesWithCommentsQueryHandler).toHaveBeenCalled();
      expect(findAllSystemNotes()).toHaveLength(0);
    });

    it('should have work item notes', () => {
      expect(workItemNotesWithCommentsQueryHandler).toHaveBeenCalled();
      expect(findAllWorkItemCommentNotes()).toHaveLength(mockDiscussions.length);
    });

    it('should pass all the correct props to work item comment note', () => {
      const commentIndex = 0;
      const firstCommentNote = findWorkItemCommentNoteAtIndex(commentIndex);

      expect(firstCommentNote.props('discussion')).toEqual(
        mockDiscussions[commentIndex].notes.nodes,
      );
    });
  });

  it('should open delete modal confirmation when child discussion emits `deleteNote` event', async () => {
    createComponent({
      defaultWorkItemNotesQueryHandler: workItemNotesWithCommentsQueryHandler,
    });
    await waitForPromises();

    findWorkItemCommentNoteAtIndex(0).vm.$emit('deleteNote', { id: '1', isLastNote: false });
    expect(showModal).toHaveBeenCalled();
  });

  describe('when modal is open', () => {
    beforeEach(() => {
      createComponent({
        defaultWorkItemNotesQueryHandler: workItemNotesWithCommentsQueryHandler,
      });
      return waitForPromises();
    });

    it('sends the mutation with correct variables', () => {
      const noteId = 'some-test-id';

      findWorkItemCommentNoteAtIndex(0).vm.$emit('deleteNote', { id: noteId });
      findDeleteNoteModal().vm.$emit('primary');

      expect(deleteWorkItemNoteMutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: noteId,
        },
      });
    });

    it('successfully removes the note from the discussion', async () => {
      expect(findWorkItemCommentNoteAtIndex(0).props('discussion')).toHaveLength(2);

      findWorkItemCommentNoteAtIndex(0).vm.$emit('deleteNote', {
        id: mockDiscussions[0].notes.nodes[0].id,
      });
      findDeleteNoteModal().vm.$emit('primary');

      await waitForPromises();
      expect(findWorkItemCommentNoteAtIndex(0).props('discussion')).toHaveLength(1);
    });

    it('successfully removes the discussion from work item if discussion only had one note', async () => {
      const secondDiscussion = findWorkItemCommentNoteAtIndex(1);

      expect(findAllWorkItemCommentNotes()).toHaveLength(2);
      expect(secondDiscussion.props('discussion')).toHaveLength(1);

      secondDiscussion.vm.$emit('deleteNote', {
        id: mockDiscussions[1].notes.nodes[0].id,
        discussion: { id: mockDiscussions[1].id },
      });
      findDeleteNoteModal().vm.$emit('primary');

      await waitForPromises();
      expect(findAllWorkItemCommentNotes()).toHaveLength(1);
    });
  });

  it('emits `error` event if delete note mutation is rejected', async () => {
    createComponent({
      defaultWorkItemNotesQueryHandler: workItemNotesWithCommentsQueryHandler,
      deleteWINoteMutationHandler: errorHandler,
    });
    await waitForPromises();

    findWorkItemCommentNoteAtIndex(0).vm.$emit('deleteNote', {
      id: mockDiscussions[0].notes.nodes[0].id,
    });
    findDeleteNoteModal().vm.$emit('primary');

    await waitForPromises();

    expect(wrapper.emitted('error')).toEqual([
      ['Something went wrong when deleting a comment. Please try again'],
    ]);
  });

  describe('Notes subscriptions', () => {
    beforeEach(async () => {
      createComponent({
        defaultWorkItemNotesQueryHandler: workItemNotesWithCommentsQueryHandler,
      });
      await waitForPromises();
    });

    it('has create notes subscription', () => {
      expect(notesCreateSubscriptionHandler).toHaveBeenCalledWith({
        noteableId: mockWorkItemId,
      });
    });

    it('has delete notes subscription', () => {
      expect(notesDeleteSubscriptionHandler).toHaveBeenCalledWith({
        noteableId: mockWorkItemId,
      });
    });

    it('has update notes subscription', () => {
      expect(notesUpdateSubscriptionHandler).toHaveBeenCalledWith({
        noteableId: mockWorkItemId,
      });
    });
  });
});
