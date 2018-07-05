namespace allpix {
    template <typename T> void MessageStorage::dispatchMessage(std::shared_ptr<T> message, const std::string& name) {
        static_assert(std::is_base_of<BaseMessage, T>::value, "Dispatched message should inherit from Message class");
        auto start = std::chrono::steady_clock::now();
        dispatch_message(module_, message, name);
        auto end = std::chrono::steady_clock::now();
        LOG(INFO) << "Dispatched message in " << static_cast<std::chrono::duration<long double, std::micro>>(end - start).count() << "μs";
    }

    template <typename T> std::shared_ptr<T> MessageStorage::fetchMessage() {
        static_assert(std::is_base_of<BaseMessage, T>::value, "Fetched message should inherit from Message class");
        auto start = std::chrono::steady_clock::now();

        auto message = std::static_pointer_cast<T>(messages_.at(module_->getUniqueName()).single);

        auto end = std::chrono::steady_clock::now();
        LOG(INFO) << "Fetched message in " << static_cast<std::chrono::duration<long double, std::micro>>(end - start).count() << "μs";

        return message;
    }

    template <typename T> std::vector<std::shared_ptr<T>> MessageStorage::fetchMultiMessage() {
        static_assert(std::is_base_of<BaseMessage, T>::value, "Fetched message should inherit from Message class");

        auto start = std::chrono::steady_clock::now();

        // Yes, use operator[] here to construct empty vector in case none exist already.
        // This mirrors the case when a listening multiMessage-module receieves no messages, so it's target vector would be
        // empty.
        auto base_messages = messages_[module_->getUniqueName()].multi;

        std::vector<std::shared_ptr<T>> derived_messages;
        for(auto& message : base_messages) {
            derived_messages.push_back(std::static_pointer_cast<T>(message));
        }

        auto end = std::chrono::steady_clock::now();
        LOG(INFO) << "Fetched multi-message in " << static_cast<std::chrono::duration<long double, std::micro>>(end - start).count() << "μs";

        return derived_messages;
    }
} // namespace allpix
