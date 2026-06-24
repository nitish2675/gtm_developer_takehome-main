import { LightningElement, api, track, wire } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import LEAFLET from '@salesforce/resourceUrl/leaflet';
import searchByCity from '@salesforce/apex/ActivityMapController.searchByCity';
import searchByRadius from '@salesforce/apex/ActivityMapController.searchByRadius';

const RECORD_FIELDS = [
    'Activity__c.Meeting_Point__Latitude__s',
    'Activity__c.Meeting_Point__Longitude__s',
    'Activity__c.City__c',
    'Activity__c.Name'
];

const CATEGORY_COLORS = {
    'Sightseeing': '#2196F3',
    'History & Culture': '#9C27B0',
    'Food & Drink': '#FF9800',
    'Outdoor & Adventure': '#4CAF50',
    'Family': '#E91E63',
    'Nightlife': '#673AB7',
    'Other': '#607D8B'
};

const CATEGORY_OPTIONS = [
    { label: 'All Categories', value: 'All' },
    { label: 'Sightseeing', value: 'Sightseeing' },
    { label: 'History & Culture', value: 'History & Culture' },
    { label: 'Food & Drink', value: 'Food & Drink' },
    { label: 'Outdoor & Adventure', value: 'Outdoor & Adventure' },
    { label: 'Family', value: 'Family' },
    { label: 'Nightlife', value: 'Nightlife' },
    { label: 'Other', value: 'Other' }
];

const GOOD_FOR_OPTIONS = [
    { label: 'All Audiences', value: 'All' },
    { label: 'Families', value: 'Families' },
    { label: 'Couples', value: 'Couples' },
    { label: 'Solo', value: 'Solo' },
    { label: 'Groups', value: 'Groups' }
];

export default class ActivityMap extends LightningElement {
    @api recordId;

    @track activities = [];
    @track totalCount = 0;
    @track isLoading = false;
    @track hasSearched = false;
    @track errorMessage = '';
    @track selectedActivityId = null;

    searchCity = '';
    selectedCategory = 'All';
    selectedGoodFor = 'All';
    radiusKm = 50;

    map;
    markers = [];
    leafletInitialized = false;
    recordDataLoaded = false;

    @wire(getRecord, { recordId: '$recordId', fields: RECORD_FIELDS })
    wiredRecord({ error, data }) {
        if (!this.recordId) return;
        if (data) {
            const lat = data.fields.Meeting_Point__Latitude__s.value;
            const lng = data.fields.Meeting_Point__Longitude__s.value;
            const city = data.fields.City__c.value;

            if (lat && lng) {
                this.performRadiusSearch(lat, lng);
                this.recordDataLoaded = true;
            } else if (city) {
                this.searchCity = city;
                this.performCitySearch();
                this.recordDataLoaded = true;
            }
        } else if (error) {
            this.errorMessage = 'Failed to load record data.';
        }
    }

    get isRecordContext() {
        return !!this.recordId;
    }

    get categoryOptions() { return CATEGORY_OPTIONS; }
    get goodForOptions() { return GOOD_FOR_OPTIONS; }
    get hasActivities() { return this.activities.length > 0; }
    get hasNoResults() { return this.hasSearched && !this.isLoading && this.activities.length === 0; }
    get showCapWarning() { return this.totalCount > 50; }
    get capWarningMessage() { return `Showing 50 of ${this.totalCount} results — filter or zoom in to narrow.`; }

    renderedCallback() {
        if (this.leafletInitialized) return;
        this.leafletInitialized = true;
        this.initLeaflet();
    }

    async initLeaflet() {
        try {
            await loadStyle(this, LEAFLET + '/leaflet/leaflet.css');
            await loadScript(this, LEAFLET + '/leaflet/leaflet.js');
            this.initMap();
        } catch (error) {
            this.errorMessage = 'Failed to load map library: ' + error.message;
        }
    }

    initMap() {
        const container = this.template.querySelector('.map-container');
        if (!container) return;

        // eslint-disable-next-line no-undef
        this.map = L.map(container, {
            center: [48.8566, 2.3522],
            zoom: 4,
            zoomControl: true
        });

        // eslint-disable-next-line no-undef
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; OpenStreetMap contributors',
            maxZoom: 19
        }).addTo(this.map);
    }

    handleCityChange(event) {
        this.searchCity = event.target.value;
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
    }

    handleGoodForChange(event) {
        this.selectedGoodFor = event.detail.value;
    }

    handleSearch() {
        if (!this.searchCity.trim()) {
            this.showToast('Enter a city', 'Please enter a city name to search.', 'warning');
            return;
        }
        this.performCitySearch();
    }

    handleKeyPress(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    async performCitySearch() {
        this.isLoading = true;
        this.errorMessage = '';
        this.hasSearched = true;

        try {
            const result = await searchByCity({
                city: this.searchCity,
                category: this.selectedCategory,
                goodFor: this.selectedGoodFor
            });

            this.activities = result.activities;
            this.totalCount = result.totalCount;
            this.renderMarkers();

            if (this.activities.length > 0) {
                this.fitMapToMarkers();
            }
        } catch (error) {
            this.errorMessage = this.extractError(error);
            this.activities = [];
        } finally {
            this.isLoading = false;
        }
    }

    async performRadiusSearch(lat, lng) {
        this.isLoading = true;
        this.errorMessage = '';
        this.hasSearched = true;

        try {
            const result = await searchByRadius({
                lat: lat,
                lng: lng,
                radiusKm: this.radiusKm,
                category: this.selectedCategory,
                goodFor: this.selectedGoodFor
            });

            this.activities = result.activities;
            this.totalCount = result.totalCount;
            this.renderMarkers();

            if (this.activities.length > 0) {
                this.fitMapToMarkers();
            }
        } catch (error) {
            this.errorMessage = this.extractError(error);
            this.activities = [];
        } finally {
            this.isLoading = false;
        }
    }

    renderMarkers() {
        this.clearMarkers();

        this.activities.forEach(activity => {
            if (activity.latitude && activity.longitude) {
                const color = CATEGORY_COLORS[activity.category] || CATEGORY_COLORS['Other'];

                // eslint-disable-next-line no-undef
                const icon = L.divIcon({
                    className: 'custom-pin',
                    html: `<div style="background-color:${color};width:14px;height:14px;border-radius:50%;border:2px solid white;box-shadow:0 2px 4px rgba(0,0,0,0.3);"></div>`,
                    iconSize: [14, 14],
                    iconAnchor: [7, 7]
                });

                // eslint-disable-next-line no-undef
                const marker = L.marker([activity.latitude, activity.longitude], { icon })
                    .addTo(this.map)
                    .bindPopup(`<strong>${activity.name}</strong><br/>${activity.category || ''}<br/>${activity.city}`);

                marker.activityId = activity.id;
                marker.on('click', () => {
                    this.handleMarkerClick(activity.id);
                });

                this.markers.push(marker);
            }
        });
    }

    clearMarkers() {
        this.markers.forEach(marker => {
            this.map.removeLayer(marker);
        });
        this.markers = [];
    }

    fitMapToMarkers() {
        if (this.markers.length === 0) return;

        // eslint-disable-next-line no-undef
        const group = L.featureGroup(this.markers);
        this.map.fitBounds(group.getBounds().pad(0.1));
    }

    handleMarkerClick(activityId) {
        this.selectedActivityId = activityId;
        this.scrollToListItem(activityId);
    }

    handleListItemClick(event) {
        const activityId = event.currentTarget.dataset.id;
        this.selectedActivityId = activityId;

        const marker = this.markers.find(m => m.activityId === activityId);
        if (marker) {
            this.map.flyTo(marker.getLatLng(), 14, { duration: 0.5 });
            marker.openPopup();
        }
    }

    scrollToListItem(activityId) {
        const listItem = this.template.querySelector(`[data-id="${activityId}"]`);
        if (listItem) {
            listItem.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }
    }

    getCategoryColor(category) {
        return CATEGORY_COLORS[category] || CATEGORY_COLORS['Other'];
    }

    get activitiesWithStyle() {
        return this.activities.map(a => ({
            ...a,
            isSelected: a.id === this.selectedActivityId,
            itemClass: 'activity-item' + (a.id === this.selectedActivityId ? ' selected' : ''),
            dotStyle: `background-color: ${this.getCategoryColor(a.category)}`
        }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractError(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'An unexpected error occurred.';
    }
}
