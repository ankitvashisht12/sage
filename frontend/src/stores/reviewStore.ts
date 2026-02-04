import { create } from "zustand";
import type { ReviewItem, FilterStatus, ItemPatch } from "@/lib/types";
import { fetchItems, patchItem } from "@/lib/api";

interface ReviewStore {
  items: ReviewItem[];
  selectedIndex: number;
  filterStatus: FilterStatus;
  searchQuery: string;
  loading: boolean;
  error: string | null;

  // Derived
  filteredIndices: number[];

  // Actions
  load: () => Promise<void>;
  select: (index: number) => void;
  setFilter: (status: FilterStatus) => void;
  setSearch: (query: string) => void;
  updateItem: (index: number, patch: ItemPatch) => Promise<void>;
  selectNext: () => void;
  selectPrev: () => void;
  selectNextPending: () => void;
}

function computeFiltered(items: ReviewItem[], filterStatus: FilterStatus, searchQuery: string): number[] {
  const q = searchQuery.toLowerCase();
  return items.reduce<number[]>((acc, item, i) => {
    // Filter by status
    if (filterStatus === "accepted" && item.accepted !== true) return acc;
    if (filterStatus === "rejected" && item.accepted !== false) return acc;
    if (filterStatus === "pending" && item.accepted !== null) return acc;

    // Filter by search
    if (q && !item.query.toLowerCase().includes(q) && !item.category.toLowerCase().includes(q) && !item.doc_id.toLowerCase().includes(q)) {
      return acc;
    }

    acc.push(i);
    return acc;
  }, []);
}

export const useReviewStore = create<ReviewStore>((set, get) => ({
  items: [],
  selectedIndex: -1,
  filterStatus: "all",
  searchQuery: "",
  loading: false,
  error: null,
  filteredIndices: [],

  load: async () => {
    set({ loading: true, error: null });
    try {
      const items = await fetchItems();
      const filteredIndices = computeFiltered(items, get().filterStatus, get().searchQuery);
      set({ items, loading: false, filteredIndices, selectedIndex: filteredIndices[0] ?? -1 });
    } catch (e) {
      set({ loading: false, error: (e as Error).message });
    }
  },

  select: (index: number) => set({ selectedIndex: index }),

  setFilter: (filterStatus: FilterStatus) => {
    const { items, searchQuery } = get();
    const filteredIndices = computeFiltered(items, filterStatus, searchQuery);
    set({ filterStatus, filteredIndices, selectedIndex: filteredIndices[0] ?? -1 });
  },

  setSearch: (searchQuery: string) => {
    const { items, filterStatus } = get();
    const filteredIndices = computeFiltered(items, filterStatus, searchQuery);
    set({ searchQuery, filteredIndices });
  },

  updateItem: async (index: number, patch: ItemPatch) => {
    const updated = await patchItem(index, patch);
    set((state) => {
      const items = [...state.items];
      items[index] = { ...items[index], ...updated };
      const filteredIndices = computeFiltered(items, state.filterStatus, state.searchQuery);
      return { items, filteredIndices };
    });
  },

  selectNext: () => {
    const { filteredIndices, selectedIndex } = get();
    const pos = filteredIndices.indexOf(selectedIndex);
    if (pos < filteredIndices.length - 1) {
      set({ selectedIndex: filteredIndices[pos + 1] });
    }
  },

  selectPrev: () => {
    const { filteredIndices, selectedIndex } = get();
    const pos = filteredIndices.indexOf(selectedIndex);
    if (pos > 0) {
      set({ selectedIndex: filteredIndices[pos - 1] });
    }
  },

  selectNextPending: () => {
    const { items, filteredIndices, selectedIndex } = get();
    const pos = filteredIndices.indexOf(selectedIndex);
    // Look forward from current position
    for (let i = pos + 1; i < filteredIndices.length; i++) {
      if (items[filteredIndices[i]].accepted === null) {
        set({ selectedIndex: filteredIndices[i] });
        return;
      }
    }
    // Wrap around
    for (let i = 0; i <= pos; i++) {
      if (items[filteredIndices[i]].accepted === null) {
        set({ selectedIndex: filteredIndices[i] });
        return;
      }
    }
  },
}));
