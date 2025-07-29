module Cacheable
  extend ActiveSupport::Concern

  private

  def cache_key_for_collection(collection, additional_params = {})
    # Create a cache key based on the collection and parameters
    cache_params = {
      collection: collection.class.name,
      count: collection.count,
      max_updated_at: collection.maximum(:updated_at)&.to_i,
      page: params[:page] || 1,
      per_page: params[:per_page] || 25
    }.merge(additional_params)

    "api/v1/#{collection.class.name.downcase.pluralize}/#{Digest::MD5.hexdigest(cache_params.to_json)}"
  end

  def cache_key_for_record(record, additional_params = {})
    # Create a cache key for a single record
    cache_params = {
      id: record.id,
      updated_at: record.updated_at.to_i
    }.merge(additional_params)

    "api/v1/#{record.class.name.downcase}/#{record.id}/#{Digest::MD5.hexdigest(cache_params.to_json)}"
  end

  def cache_with_etag(collection, additional_params = {})
    cache_key = cache_key_for_collection(collection, additional_params)
    
    Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
      yield
    end
  end

  def cache_record_with_etag(record, additional_params = {})
    cache_key = cache_key_for_record(record, additional_params)
    
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      yield
    end
  end

  def invalidate_cache_for(record)
    # Invalidate cache when a record is updated
    cache_key = cache_key_for_record(record)
    Rails.cache.delete(cache_key)
    
    # Also invalidate collection cache
    collection_cache_key = cache_key_for_collection(record.class.all)
    Rails.cache.delete(collection_cache_key)
  end

  def cache_api_response(key, expires_in: 15.minutes)
    Rails.cache.fetch(key, expires_in: expires_in) do
      yield
    end
  end
end 